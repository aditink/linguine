open Lin_ops

type value = CoreAst.value

let dot (v1 : vec) (v2 : vec) : float =
  List.fold_left2 (fun acc x y -> acc +. (x *. y)) 0. v1 v2

let normalize (v : vec) : vec = 
  let distance = sqrt (List.fold_left (fun acc x -> acc +. (x *. x)) 0. v) in
  List.map (fun x -> x /. distance) v

let rec make_list (v : 'a) (length : int) : 'a list =
  if length < 0 then failwith "Cannot make a vector with length < 0"
  else if length = 0 then [] else v::(make_list v (length - 1))
let rec vec_expand (length : int) (vals : value list) : vec =
  match vals with
  | [] -> make_list 0. length
  | h::t -> (match h with
    | Num n -> (float_of_int n)::(vec_expand (length - 1) t)
    | Float f -> f::(vec_expand (length - 1) t)
    | VecLit v -> v@(vec_expand (length - (List.length v)) t)
    | _ -> failwith ("Bad argument to vecn " ^ (Util.string_of_value h))
  )
let rec vec_contract(length : int) (v : vec) : vec =
  match v with
  | [] -> []
  | h::t -> if (length > 0) then h::(vec_contract (length - 1) t) else []

let vecn (length : int) (args : value list) : vec =
  match args with
  | [] -> make_list 0. length
  | [Num n] -> make_list (float_of_int n) length 
  | [Float f] -> make_list f length 
  | [VecLit v] -> 
    if length < List.length v then vec_contract length v else vec_expand length args
  | _ -> vec_expand length args

let vec_with_f_index (length : int) (f : float) (index : int) : vec =
  let rec vec_with_f_index_helper (wr_index : int) (length_minus_index : int) : vec =
    if wr_index - 1 == length_minus_index then f::(make_list 0. (wr_index - 1))
    else 0.::(vec_with_f_index_helper (wr_index - 1) length_minus_index)
  in
  if length < 0 then failwith "Cannot make a vector with length < 0" else
  if index >= length || index < 0 then failwith ("Bad index " ^ (string_of_int index)) else
  vec_with_f_index_helper length (length - index - 1)

let matf (size : int) (f : float) : mat =
  let rec __matf (size : int) (row : int) (f : float) : mat =
    if row >= size then []
    else (vec_with_f_index size f row)::(__matf size (row + 1) f)
  in
  __matf size 0 f

(* This is tricky cause we don't have the syntax divisions for each vector *)
let rec matfs (size : int) (fs : float list) : mat =
  let rec add_to_nth_list (f : float) (lst_index : int) (lsts : (float list) list) : mat =
    match lsts with
    | [] -> failwith "bad lst_index"
    | h::t -> if ((List.length lsts) - 1) == lst_index then
      (f::h)::t else h::(add_to_nth_list f lst_index t)
  in
  match fs with
  | [] -> make_list [] size
  | h::t -> add_to_nth_list h (((List.length fs) - 1) mod size) (matfs size t)

let matvs (vs : vec list) : mat =
  transpose vs

let mat_expand (size : int) (m : mat) : mat =
  let rec build_base (row : int) (endpoint : int) : mat =
    if row = endpoint then []
    else vec_with_f_index size 1. row::(build_base (row - 1) endpoint)
  in
  let lm = (List.length m) in
  (List.map (fun v -> (v@(make_list 0. (size - lm)))) m)@
  (build_base (size - 1) (lm - 1))

let mat_contract (size : int) (m : mat) : mat =
  let rec remove_end index m_mod =
    match m_mod with
    | [] -> []
    | h::t -> if index >= size then []
      else (vec_contract size h)::(remove_end (index + 1) t)
  in
  remove_end 0 m

let matn (size : int) (args : value list) : mat =
  let fail_text = "Cannot construct a matrix as given (not a supported GLSL constructor?)" in
  let rec as_fs (args : value list) : float list =
    match args with
    | [] -> []
    | Float f::t -> f::(as_fs t)
    | _ -> failwith fail_text
  in
  let rec as_vs (args : value list) : vec list =
    match args with
    | [] -> []
    | VecLit v::t -> v::(as_vs t)
    | _ -> failwith fail_text
  in
  match args with
  | [] -> matf size 0.
  | [Float f] -> matf size f
  | [MatLit m] ->
    if size < List.length m then mat_contract size m else mat_expand size m
  | _ -> (match (List.hd args) with 
    | Float _ -> matfs size (as_fs args)
    | VecLit _ -> matvs (as_vs args)
    | _ -> failwith fail_text)
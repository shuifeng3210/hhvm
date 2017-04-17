(**
 * Copyright (c) 2017, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
*)

open Core

module A = Ast
module H = Hhbc_ast

(* Taken from: hphp/runtime/base/type-structure.h *)
let get_kind p = Int64.of_int @@
  match p with
  | "void" -> 0
  | "int" -> 1
  | "bool" -> 2
  | "float" -> 3
  | "string" -> 4
  | "resource" -> 5
  | "num" -> 6
  | "noreturn" -> 8
  | "arraykey" -> 7
  | "mixed" -> 9
  | "tuple" -> 10
  | "fun" -> 11
  | "array" -> 12
  | "typevar" -> 13 (* corresponds to user OF_GENERIC *)
  | "shape" -> 14
  | "class" -> 15
  | "interface" -> 16
  | "trait" -> 17
  | "enum" -> 18
  | "dict" -> 19
  | "vec" -> 20
  | "keyset" -> 21
  | "unresolved" -> 101
  | "typeaccess" -> 102
  | "xhp" -> 103
  | s -> failwith @@ "Type constant: No such kind exists for: " ^ s

let shape_field_name = function
  | A.SFlit ((_, s)) -> s, false
  | A.SFclass_const ((_, id), (_, s)) -> id ^ "::" ^ s, true

let rec shape_field_to_instr_lit_list sf =
  let name, is_class_const = shape_field_name sf.A.sf_name in
  (* TODO: Optional? *)
  let hint = sf.A.sf_hint in
  let class_const =
    if is_class_const then [H.String "is_cls_cns"; H.True] else []
  in
  let inner_value =
    class_const @ [H.String "value"; hint_to_type_constant hint]
  in
  let value = H.Array (List.length inner_value / 2, inner_value) in
  [H.String name; value]

and shape_info_to_instr_lit si =
  let l = si.A.si_shape_field_list in
  H.Array (List.length l,
      List.concat @@ List.map ~f:shape_field_to_instr_lit_list l)

and type_constant_access_list sl =
  let l =
    List.mapi ~f:(fun i (_, s) -> [H.Int (Int64.of_int i); H.String s]) sl
  in
  H.Array (List.length sl, List.concat l)

and hint_to_type_constant_list h =
  match snd h with
  | A.Happly ((_, s), []) ->
    [H.String "kind"; H.Int (get_kind s)]
  | A.Hshape (si) ->
    [H.String "kind"; H.Int (get_kind "shape");
     H.String "fields"; shape_info_to_instr_lit si]
  | A.Haccess ((_, s0), s1, sl) ->
    [H.String "kind"; H.Int (get_kind "typeaccess");
    H.String "root_name"; H.String s0;
    H.String "access_list"; type_constant_access_list @@ s1::sl]
  | _ -> [H.String "kind"; H.NYI "type_constants"]

and hint_to_type_constant h =
  let l = hint_to_type_constant_list h in
  let count = List.length l in
  let count =
    if count mod 2 = 0
    then count / 2
    else failwith "hint_to_type_constant - odd length"
  in
  H.Array (count, l)

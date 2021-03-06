(*
 * Copyright (c) 2019, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the "hack" directory of this source tree.
 *
 *)

module Decl_cache_entry = struct
  (* NOTE: we can't simply use a string as a key. In the case of a name
  conflict, we may put e.g. a function named 'foo' into the cache whose value is
  one type, and then later try to withdraw a class named 'foo' whose value is
  another type.

  The actual value type for [Class_decl] is a [Typing_classes_heap.Classes.t],
  but that module depends on this module, so we can't write it down or else we
  will cause a circular dependency. (It could probably be refactored to break
  the dependency.) We just use [Obj.t] instead, which is better than using
  [Obj.t] for all of the cases here.
  *)
  type _ t =
    | Fun_decl : string -> Typing_defs.fun_elt t
    | Class_decl : string -> Obj.t t
    | Record_decl : string -> Typing_defs.record_def_type t
    | Typedef_decl : string -> Typing_defs.typedef_type t
    | Gconst_decl : string -> (Typing_defs.decl_ty * Errors.t) t

  type 'a key = 'a t

  type 'a value = 'a

  let get_size ~key:_ ~value:_ = 1
end

module Decl_cache = Lru_cache.Cache (Decl_cache_entry)

type t =
  | Shared_memory
  | Local_memory of { decl_cache: Decl_cache.t }
  | Decl_service of Decl_service_client.t

let t_to_string (t : t) : string =
  match t with
  | Shared_memory -> "Shared_memory"
  | Local_memory _ -> "Local_memory"
  | Decl_service _ -> "Decl_service"

let backend_ref = ref Shared_memory

let set_shared_memory_backend () : unit = backend_ref := Shared_memory

let set_local_memory_backend ~(max_num_decls : int) : unit =
  backend_ref :=
    Local_memory { decl_cache = Decl_cache.make ~max_size:max_num_decls }

let set_decl_service_backend (decl : Decl_service_client.t) : unit =
  backend_ref := Decl_service decl

let get () : t = !backend_ref

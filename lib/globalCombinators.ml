type ('obj, 'ot, 'var, 'vt) label = {
  obj : ('obj, 'ot) Rows.method_;
  var : ('var, 'vt) Rows.constr;
}

type ('t, 'u, 'ts, 'us, 'robj, 'mt) role = {
  role_index : ('t, 'u, 'ts, 'us) Hlist.idx;
  role_label : ('robj, 'mt) Rows.method_;
}

module Open = struct
  type _ t =
    | [] : ([ `cons of unit * 'a ] as 'a) t
    | ( :: ) : (unit, 'b, 'bb, 'cc, _, _) role * 'bb t -> 'cc t
end

module Sessions = Hlist.Make (State)
open Sessions

type 'a seq = 'a Hlist.Make(State).seq =
  | ( :: ) : 'hd State.t * 'tl seq -> [ `cons of 'hd * 'tl ] seq
  | [] : ([ `cons of unit * 'a ] as 'a) seq

type 's out = 's Chvec.out
type 's inp = 's Chvec.inp

exception UnguardedLoop = State.UnguardedLoop

let select = Chvec.select
let branch = Chvec.branch
let close () = ()

let ( --> ) ra rb lab g =
  let key = Name.make () in
  let b = seq_get rb.role_index g in
  let g = seq_put rb.role_index g (Chvec.inp ra.role_label lab.var key b) in
  let a = seq_get ra.role_index g in
  let g = seq_put ra.role_index g (Chvec.out rb.role_label lab.obj key a) in
  g

let rec merge_seq : type t. t seq -> t seq -> t seq =
 fun ls rs ->
  match (ls, rs) with
  | Sessions.[], _ -> []
  | _, [] -> []
  | l :: ls, r :: rs -> State.merge l r :: merge_seq ls rs

let choice_at ra disj (ra1, g1) (ra2, g2) =
  let a1 = seq_get ra1.role_index g1 and a2 = seq_get ra2.role_index g2 in
  let g1 = seq_put ra1.role_index g1 State.unit
  and g2 = seq_put ra2.role_index g2 State.unit in
  let g = merge_seq g1 g2 in
  let a = State.internal_choice disj a1 a2 in
  seq_put ra.role_index g a

let partial_finish keep_idxs g =
  let rec make_partial_finish :
      type b. keep_idxs:b Open.t -> keeps:b seq lazy_t -> b seq =
   fun ~keep_idxs ~keeps ->
    match keep_idxs with
    | Open.[] -> Sessions.[]
    | idx :: rest_idxs ->
        let state =
          (* get the state of the involved role *)
          State.loop (lazy (seq_get2 idx.role_index (Lazy.force keeps)))
        and rest =
          (* rest of the states *)
          lazy (seq_put2 idx.role_index (Lazy.force keeps) State.unit)
        in
        let states = make_partial_finish ~keep_idxs:rest_idxs ~keeps:rest in
        (* put the state and return it *)
        seq_put idx.role_index states state
  in
  make_partial_finish ~keep_idxs ~keeps:g

let fix_with keep_idxs f =
  let rec self = lazy (partial_finish keep_idxs (lazy (f (Lazy.force self)))) in
  Lazy.force self

let finish = Sessions.[]

let rec extract : type u. u Sessions.seq -> u = function
  | Sessions.[] ->
      let rec nil = `cons ((), nil) in
      nil
  | st :: tail ->
      let hd = State.determinise st in
      let tl = extract tail in
      `cons (hd, tl)

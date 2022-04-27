type 'a many = 'a State.t list

let get_many ss = List.map State.determinise ss

let det_list_ops (type b) (module D : State.DetState with type a = b) =
  let module DetList = struct
    type nonrec a = b many

    let determinise _ctx s = s
    let merge _ctx s1 s2 = List.map2 State.merge s1 s2
    let force _ctx _ss = ()
    (* let ss = List.map (State.determinise_core (State.Context.make ())) ss in
       List.iter (State.force_core (State.Context.make ())) ss *)

    let to_string _ctx _s = "<multicast>"
  end in
  (module DetList : State.DetState with type a = b many)

let units ~count =
  let module Unit = struct
    type a = unit

    let determinise _ _ = ()
    let merge _ _ _ = ()
    let force _ _ = ()
    let to_string _ _ = "end"
  end in
  let unit_ops = (module Unit : State.DetState with type a = unit) in
  State.make_deterministic (State.Context.new_key ())
    begin
      lazy
      State.
        {
          det_state = List.init count (fun _i -> State.unit);
          det_ops = det_list_ops unit_ops;
        }
    end

let outs ~count role lab names (ss : _ many State.t) : _ many State.t =
  let ss =
    lazy
      (let ss = State.determinise ss in
       ss)
  in
  let ss =
    List.init count (fun i ->
        State.make_lazy (lazy (List.nth (Lazy.force ss) i)))
  in
  State.make_deterministic (State.Context.new_key ())
    (lazy
      State.
        {
          det_state =
            List.mapi
              (fun _i (name, s) -> ActionOut.make_out role lab name s)
              (List.combine names ss);
          det_ops = det_list_ops (ActionOut.out_ops role lab);
        })

let inps ~count role constr names (ss : _ many State.t) : _ many State.t =
  let ss =
    lazy
      (let ss = State.determinise ss in
       ss)
  in
  let ss =
    List.init count (fun i ->
        State.make_lazy (lazy (List.nth (Lazy.force ss) i)))
  in
  State.make_deterministic (State.Context.new_key ())
    (lazy
      State.
        {
          det_state =
            List.mapi
              (fun _i (name, s) -> ActionInp.make_inp role constr name s)
              (List.combine names ss);
          det_ops = det_list_ops (ActionInp.inp_ops role);
        })
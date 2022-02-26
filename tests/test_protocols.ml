open Mpst2.GlobalCombinators
open Rows
open OUnit

module Util = struct
  [%%declare_roles_prefixed a, b, c, d]
  [%%declare_labels msg, left, right, middle, ping, pong, fini]

  let to_ m r1 r2 r3 =
    let ( ! ) x = x.role_label in
    {
      disj_concat =
        (fun l r ->
          !r1.make_obj (m.disj_concat (!r2.call_obj l) (!r3.call_obj r)));
      disj_splitL = (fun lr -> !r2.make_obj (m.disj_splitL @@ !r1.call_obj lr));
      disj_splitR = (fun lr -> !r3.make_obj (m.disj_splitR @@ !r1.call_obj lr));
    }

  let to_a m = to_ m a a a
  let to_b m = to_ m b b b
  let to_c m = to_ m c c c
  let to_d m = to_ m d d d
end

open Util

let test_failfast () =
  let bottom () = fix_with [ a; b; c ] (fun t -> t) in
  assert_raises UnguardedLoop ~msg:"bottom" (fun _ ->
      ignore @@ extract @@ bottom ());
  assert_raises UnguardedLoop ~msg:"bottom after comm" (fun _ ->
      ignore @@ extract @@ (a --> b) msg @@ bottom ());
  assert_raises UnguardedLoop ~msg:"bottom after choice" (fun _ ->
      ignore
      @@ extract
      @@ choice_at a
           (to_b [%disj left, right])
           (a, (a --> b) left @@ (b --> c) middle @@ bottom ())
           (a, (a --> b) right @@ (b --> c) middle finish));
  assert_raises UnguardedLoop ~msg:"bottom after choice 2" (fun _ ->
      ignore
      @@ extract
      @@ choice_at a
           (to_b [%disj left, right])
           (a, bottom ())
           (a, (a --> b) right @@ (b --> c) middle finish));
  assert_raises UnguardedLoop ~msg:"bottom after choice 3" (fun _ ->
      ignore
      @@ extract
      @@ choice_at b
           (to_b [%disj left, right])
           (c, (c --> b) left @@ (b --> a) middle @@ bottom ())
           (c, (c --> b) right @@ (b --> a) middle finish));
  assert_raises UnguardedLoop ~msg:"bottom after choice loop" (fun _ ->
      ignore
      @@ extract
      @@ fix_with [ a; b; c ]
      @@ fun t ->
      choice_at a
        (to_b [%disj left, right])
        (a, (a --> b) left @@ (b --> c) middle t)
        (a, (a --> b) right @@ (b --> c) middle @@ bottom ()));
  assert_raises UnguardedLoop ~msg:"bottom after choice loop 2" (fun _ ->
      ignore
      @@ extract
      @@ fix_with [ a; b; c ]
      @@ fun t ->
      choice_at c
        (to_b [%disj left, right])
        (c, (c --> b) left t)
        (c, (c --> b) right t));
  assert_raises UnguardedLoop ~msg:"bottom after choice loop 3" (fun _ ->
      ignore
      @@ extract
      @@ choice_at b
           (to_a [%disj left, right])
           ( b,
             (b --> a) left
             @@ fix_with [ a; b; c ]
             @@ fun t ->
             choice_at c
               (to_b [%disj left, right])
               (c, (c --> b) left t)
               (c, (c --> b) right t) )
           ( b,
             (b --> a) right
             @@ fix_with [ a; b; c ]
             @@ fun t ->
             choice_at c
               (to_b [%disj left, right])
               (c, (c --> b) left t)
               (c, (c --> b) right t) ));
  assert_raises UnguardedLoop ~msg:"bottom after choice loop 4" (fun _ ->
      let cd =
        fix_with [ a; b; c; d ] @@ fun t ->
        choice_at c
          (to_d [%disj left, right])
          (c, (c --> d) left t)
          (c, (c --> d) right t)
      in
      ignore
      @@ extract
      @@ choice_at b (to_a [%disj left, right]) (b, cd) (b, (b --> a) right cd));
  assert_raises UnguardedLoop ~msg:"loop merge" (fun _ ->
      ignore
      @@ extract
      @@ choice_at a
           (to_b [%disj left, right])
           ( a,
             (a --> b) left
             @@ fix_with [ a; b; c ] (fun t ->
                    choice_at a
                      (to_b [%disj left, right])
                      (a, (a --> b) left t)
                      (a, (a --> b) right t)) )
           (a, (a --> b) right @@ (a --> b) left @@ (b --> c) left finish))

let suite = "Test Mpst2 module" >::: [ "test_failfast" >:: test_failfast ];;

let _results = run_test_tt_main suite in
()

let () =
  let _g = extract @@ (a --> b) msg finish in
  let _g =
    extract
    @@ choice_at a
         (to_b [%disj left, right])
         (a, (a --> b) left finish)
         (a, (a --> b) right finish)
  in
  let _g = extract @@ fix_with [ a; b ] (fun t -> (a --> b) msg t) in
  let _g8 =
    extract
    @@ fix_with [ a; b; c ] (fun t ->
           choice_at a
             (to_b [%disj left, right])
             (a, (a --> b) left @@ (b --> c) middle t)
             (a, (a --> b) right @@ (b --> c) middle t))
  in
  let _g5 =
    extract
    @@ fix_with [ a; b; c ] (fun t ->
           choice_at a
             (to_b [%disj left, right])
             (a, (a --> b) left @@ (b --> c) msg t)
             (a, (a --> b) right @@ (b --> c) msg @@ (b --> c) left finish))
  in
  ()

let () =
  print_endline "g7";
  let _g7 =
    extract
    @@ fix_with [ a; b ] (fun t ->
           (a --> b) left
           @@ fix_with [ a; b ] (fun u ->
                  choice_at a
                    (to_b [%disj left, right])
                    (a, t)
                    (a, (a --> b) right @@ u)))
  in
  let (`cons ((sa : 'sa7), `cons ((sb : 'sb7), _))) = _g7 in
  let _ta =
    Thread.create
      (fun () ->
        let rec loop sa i =
          print_endline "select";
          if i < 5 then (
            print_endline "select right";
            loop (select sa#role_B#right) (i + 1))
          else if i < 10 then (
            print_endline "select left";
            loop (select sa#role_B#left) (i + 1))
          else ()
        in
        loop (select sa#role_B#left) 0)
      ()
  in
  let _tb =
    Thread.create
      (fun () ->
        let rec loop (sb : 'sb7) =
          print_endline "branch";
          match branch sb#role_A with
          | `left sb ->
              print_endline "g7: tb: left";
              loop sb
          | `right sb ->
              print_endline "g7: tb: right";
              loop sb
        in
        loop sb)
      ()
  in
  Thread.join _ta

let () =
  let _g6 =
    print_endline "g6 determinising";
    extract
    @@ choice_at a
         (to_b [%disj left, right])
         (a, fix_with [ a; b; c ] (fun t -> (a --> b) left @@ (a --> c) msg t))
         (a, fix_with [ a; b; c ] (fun t -> (a --> b) right @@ (a --> c) msg t))
  in
  print_endline "g6 determinised";
  let (`cons (_sa, `cons (_sb, `cons (_sc, _)))) = _g6 in
  let _ta =
    Thread.create
      (fun () ->
        print_endline "ta start";
        let rec loop sa i =
          if i > 100 then ()
          else (
            if i mod 10 = 0 then (
              Printf.printf "%d\n" i;
              flush stdout);
            let sa = select sa#role_B#left in
            let sa = select sa#role_C#msg in
            loop sa (i + 1))
        in
        loop
          (_sa
            :> < role_B : < left : < role_C : < msg : 'a out > > out > > as 'a)
          0;
        print_endline "g6: ta finish")
      ()
  in
  let _tb =
    Thread.create
      (fun () ->
        print_endline "tb start";
        let rec loop sb i =
          if i mod 10 = 0 then (
            Printf.printf "%d\n" i;
            flush stdout);
          match branch sb#role_A with
          | `left sb -> loop sb (i + 1)
          | `right sb -> loop sb (i + 1)
        in
        loop _sb 0)
      ()
  in
  let _tc =
    Thread.create
      (fun () ->
        let rec loop sc =
          let (`msg sc) = branch sc#role_A in
          loop sc
        in
        loop _sc)
      ()
  in
  Thread.join _ta

let () =
  let _g4 =
    extract
    @@ fix_with [ a; b; c ] (fun t ->
           choice_at a
             (to_b [%disj [ left; middle ], right])
             ( a,
               choice_at a
                 (to_b [%disj left, middle])
                 (a, (a --> b) left t)
                 (a, (a --> b) middle t) )
             (a, (a --> b) right @@ (a --> c) msg finish))
  in
  let (`cons ((sa : 'ta), `cons ((sb : 'tb), `cons ((sc : 'tc), _)))) = _g4 in
  let _t1 =
    Thread.create
      (fun () ->
        let rec loop (sa : 'ta) i =
          if i < 5 then loop (select sa#role_B#left) (i + 1)
          else if i < 10 then loop (select sa#role_B#middle) (i + 1)
          else select (select sa#role_B#right)#role_C#msg
        in
        loop sa 0;
        print_endline "g4: ta finished")
      ()
  in
  let _t2 =
    Thread.create
      (fun () ->
        let rec loop (sb : 'tb) =
          match branch sb#role_A with
          | `left sb -> loop sb
          | `middle sb -> loop sb
          | `right sb -> close sb
        in
        loop sb;
        print_endline "g4: tb finished")
      ()
  in
  let _t3 =
    Thread.create
      (fun () ->
        let loop (sc : 'tc) =
          let (`msg sc) = branch sc#role_A in
          close sc
        in
        loop sc;
        print_endline "g4: tc finished")
      ()
  in
  List.iter Thread.join [ _t1; _t2; _t3 ]

let () =
  let _g3 =
    extract
    @@ fix_with [ a; b; c ] (fun t ->
           (a --> b) msg
           @@ choice_at a
                (to_c [%disj left, right])
                (a, (a --> c) left @@ (c --> a) msg t)
                (a, (a --> c) right @@ (c --> a) msg t))
  in
  let (`cons (sa, `cons (sb, `cons (sc, _)))) = _g3 in
  let _t1 =
    Thread.create
      (fun () ->
        let rec loop sa i =
          let sa = select sa#role_B#msg in
          if i < 5 then
            let (`msg sa) = branch (select sa#role_C#left)#role_C in
            loop sa (i + 1)
          else if i < 10 then
            let (`msg sa) = branch (select sa#role_C#right)#role_C in
            loop sa (i + 1)
          else print_endline "g3: t1: stop"
        in
        loop sa 0)
      ()
  in
  let _t2 =
    Thread.create
      (fun () ->
        let rec loop sb =
          let (`msg sb) = branch sb#role_A in
          loop sb
        in
        loop sb)
      ()
  in
  let _t3 =
    Thread.create
      (fun () ->
        let rec loop sc =
          match branch sc#role_A with
          | `left sc -> loop (select sc#role_A#msg)
          | `right sc -> loop (select sc#role_A#msg)
        in
        loop sc)
      ()
  in
  ()

let () =
  let _g2 =
    extract
    @@ fix_with [ a; b; c ] (fun t ->
           (a --> b) left
           @@ choice_at a
                (to_b [%disj left, right])
                (a, t)
                (a, (a --> b) right @@ (b --> c) right @@ finish))
  in
  let (`cons (sa, `cons (sb, `cons (sc, _)))) = _g2 in
  let _ta =
    Thread.create
      (fun () ->
        let rec loop sa i =
          if i < 10 then loop (select sa#role_B#left) (i + 1)
          else close (select sa#role_B#right)
        in
        loop (select sa#role_B#left) 0;
        print_endline "g2: ta finished")
      ()
  in
  let _tb =
    Thread.create
      (fun () ->
        let rec loop sb =
          match branch sb#role_A with
          | `left sb -> loop sb
          | `right sb -> close (select sb#role_C#right)
        in
        loop sb;
        print_endline "g2: tb finished")
      ()
  in
  let (`right sc) = branch sc#role_B in
  close sc;
  print_endline "g2: tc finished"

let () =
  let _g1 =
    extract
    @@ fix_with [ a; b; c ] (fun t ->
           choice_at a
             (to_b [%disj left, right])
             (a, (a --> b) left t)
             (a, (a --> b) right @@ (b --> c) right finish))
  in
  let (`cons (sa, `cons (sb, `cons (sc, _)))) = _g1 in
  let _ta =
    Thread.create
      (fun () ->
        let rec loop sa i =
          if i < 1000 then
            let sa = select sa#role_B#left in
            loop sa (i + 1)
          else close (select sa#role_B#right)
        in
        loop sa 0;
        print_endline "g1: ta finish")
      ()
  in
  let _tb =
    Thread.create
      (fun () ->
        let rec loop sb acc =
          match branch sb#role_A with
          | `left sb -> loop sb (acc + 1)
          | `right sb ->
              close (select sb#role_C#right);
              acc
        in
        Printf.printf "%d\n" @@ loop sb 0;
        flush stdout)
      ()
  in
  let (`right sc) = branch sc#role_B in
  close sc

let () =
  let _g0 =
    extract
    @@ choice_at a
         (to_b [%disj left, right])
         (a, fix_with [ a; b ] (fun t -> (a --> b) left t))
         (a, fix_with [ a; b ] (fun t -> (a --> b) right t))
  in
  let (`cons (sa, `cons (sb, _))) = _g0 in
  let ta =
    Thread.create
      (fun () ->
        print_endline "ta start";
        let rec f sa i =
          if i > 10000 then ()
          else (
            if i mod 1000 = 0 then Printf.printf "%d\n" i;
            flush stdout;
            let sa = select sa#role_B#left in
            f sa (i + 1))
        in
        f (sa :> < role_B : < left : 'b out > > as 'b) 0;
        print_endline "g0: ta finish")
      ()
  in
  let _tb =
    Thread.create
      (fun () ->
        print_endline "tb start";
        let rec f sb i =
          (* begin
               if i mod 10 = 0 then
                 Printf.printf "%d\n" i;
             end; *)
          match branch sb#role_A with
          | `left sb ->
              (* print_endline "tb: left"; *)
              f sb (i + 1)
          | `right sb ->
              (* print_endline "tb: right"; *)
              f sb (i + 1)
        in
        f sb 0)
      ()
  in
  Thread.join ta

let () =
  let _g9 =
    extract
    @@ fix_with [ a; b; c ] (fun t1 ->
           choice_at a
             (to_b [%disj left, [ middle; right ]])
             (a, (a --> b) left @@ (a --> c) left finish)
             ( a,
               fix_with [ a; b; c ] (fun t2 ->
                   choice_at a
                     (to_b [%disj middle, right])
                     (a, (a --> b) middle @@ (a --> c) middle t2)
                     (a, (a --> b) right @@ t1)) ))
  in
  let (`cons ((sa : 'sa9), `cons ((sb : 'sb9), `cons ((sc : 'sc9), _)))) =
    _g9
  in
  let _ta =
    Thread.create
      (fun () ->
        let rec loop1 (sa : 'sa9) x =
          match x with
          | _ when x < 0 ->
              print_endline "A: select left at loop1";
              select (select sa#role_B#left)#role_C#left
          | 1 ->
              print_endline "A: select middle at loop1";
              loop2 (select (select sa#role_B#middle)#role_C#middle) (x - 1)
          | _ ->
              print_endline "A: select right at loop1";
              loop1 (select sa#role_B#right) (x - 1)
        and loop2 sa x =
          match x with
          | _ when x > 0 ->
              print_endline "A: select middle at loop2";
              loop2 (select (select sa#role_B#middle)#role_C#middle) (x - 1)
          | _ ->
              print_endline "A: select right at loop2";
              loop1 (select sa#role_B#right) (x - 1)
        in
        loop1 sa 1)
      ()
  and _tb =
    Thread.create
      (fun () ->
        let rec loop (sb : 'sb9) =
          match branch sb#role_A with
          | `left sb ->
              print_endline "B: left";
              close sb
          | `middle sb ->
              print_endline "B: middle";
              loop sb
          | `right sb ->
              print_endline "B: right";
              loop sb
        in
        loop sb)
      ()
  and _tc =
    Thread.create
      (fun () ->
        let rec loop (sc : 'sc9) =
          match branch sc#role_A with
          | `left sc ->
              print_endline "C: left";
              close sc
          | `middle sc ->
              print_endline "C: middle";
              loop sc
        in
        loop sc)
      ()
  in
  List.iter Thread.join [ _ta; _tb; _tc ]

let () =
  let _g10 =
    fix_with [ a; b; c ] (fun t ->
        choice_at a
          (to_b [%disj left, right])
          (a, (a --> b) left @@ (a --> c) msg t)
          (a, (a --> b) right @@ (a --> c) msg t))
  in
  let (`cons (_, `cons (_, _))) = extract _g10 in
  ()

let () = print_endline "ok"
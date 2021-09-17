
type 'a name_ =
| Name of 'a Event.channel
| Link of 'a t
and 'a t = 'a name_ ref

let make () =
  ref @@ Name (Event.new_channel ())

let rec unify (n1:'a t) (n2:'a t) =
  if n1==n2 then 
    () 
  else
    match !n1,!n2 with
    | Name _, Name _ -> n2 := Link n1
    | Link n1, _ -> unify n1 n2
    | _, Link n2 -> unify n1 n2

let rec finalise n1 =
  match !n1 with
  | Name ch -> ch
  | Link n1' -> 
    let ch = finalise n1' in
    n1 := Name ch;
    ch
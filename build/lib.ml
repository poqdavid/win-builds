type poison = Poison

let (^/) = Filename.concat

let cri = 0
let err = 1
let wrn = 2
let inf = 3
let dbg = 4

let log_threshold =
  try
    match Sys.getenv "LOGLEVEL" with
    | "CRI" | "cri" -> cri
    | "ERR" | "err" -> err
    | "WRN" | "wrn" -> wrn
    | "INF" | "inf" -> inf
    | "DBG" | "dbg" -> dbg
    | s -> try int_of_string s with _ -> inf
  with _ -> inf

let log level =
  (if log_threshold >= level then Printf.fprintf else Printf.ifprintf) stderr

let cond_log level b s =
  (if not b then log level s); b

let progress = Printf.printf

let cond_progress b s =
  (if not b then progress s); b

let sp = Printf.sprintf

type command = {
  cmd : string;
  pid : int;
}

let waitpid log_level command =
  let f = log log_level in
  match snd (Unix.waitpid [] command.pid) with
  | Unix.WEXITED i ->
      f "Command `%s' returned %d.\n%!" command.cmd i;
      if i <> 0 then failwith (sp "Failed process [%d]: `%s'\n'" i command.cmd)
  | Unix.WSIGNALED i ->
      f "Command `%s' has been signaled with signal %d.\n%!" command.cmd i
  | Unix.WSTOPPED i ->
      f "Command `%s' has been stopped with signal %d.\n%!" command.cmd i

let run ?(stdin=Unix.stdin) ?(stdout=Unix.stdout) ?(stderr=Unix.stderr) ?env a =
  let cmd = String.concat " " (Array.to_list a) in
  log dbg "Running `%s'%!" cmd;
  let env = match env with
    | None -> Unix.environment ()
    | Some env -> env
  in
  log dbg ", env = { %s }%!" (String.concat ", " (Array.to_list env));
  let pid = Unix.create_process_env a.(0) a env stdin stdout stderr in
  log dbg ", pid = %d.\n%!" pid;
  (fun () -> waitpid dbg { pid = pid; cmd = cmd })

let make_path_absolute_if_not path =
  let cwd = Sys.getcwd () in
  if Filename.is_relative path then
    cwd ^/ path
  else
    path

let may f = function
  | Some x -> f x
  | None -> ()

let work_dir =
  if Array.length Sys.argv < 2 then (
    log cri "Not enough arguments.\n%!";
    exit 1
  )
  else
    make_path_absolute_if_not Sys.argv.(1)

let version = Sys.getenv "VERSION"

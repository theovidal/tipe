(*
         _________  ___  ________  _______      
        |\___   ___\\  \|\   __  \|\  ___ \     
        \|___ \  \_\ \  \ \  \|\  \ \   __/|    
             \ \  \ \ \  \ \   ____\ \  \_|/__  
              \ \  \ \ \  \ \  \___|\ \  \_|\ \ 
               \ \__\ \ \__\ \__\    \ \_______\
                \|__|  \|__|\|__|     \|_______|
                                        
Tracing of paths for reconnaissance of an earthquake zone by drone
 Simulated annealing algorithm to trace paths in a specified zone
                   VIDAL Théo - 962 MPI*
*)

(* A permutation is a tuple of an integer n and two arrays of size n *)
type permutation = int * int array * int array

(* Generate a random integer between a and b, except a and b *)
let random_except n a b =
  let c = ref a in
  while !c == a || !c == b do
    c := Random.int n
  done;
  !c

(* Copy an array into another one *)
let copy src dest =
  Array.iteri (fun i x -> dest.(i) <- x) src

(* Generate a random permutation with the Fisher-Yates shuffle *)
let basic_permutation n : permutation =
  let sigma = Array.init n (fun i -> i + 1) in
  let sigmainv = Array.init n (fun i -> i - 1) in
  sigma.(n - 1) <- 0;
  sigmainv.(0) <- n - 1;
  (n, sigma, sigmainv)

let permute ?(transformation = -2) ?(a = -1) points (n, sigma, sigmainv : permutation) : float * int * int =
  let a = (if a = -1 then Random.int n else a) in
  let b = sigma.(a) in
  let invA = sigmainv.(a) in
  let nextB = sigma.(b) in

  (* Apply the chosen transformation to the path, or a random one *)
  match transformation with
  | -2 ->
    if Random.int 2 == 0 then (* REVERSE *)
         Utils.distance2 points.(invA) points.(b)
      +. Utils.distance2 points.(a) points.(nextB)
      -. Utils.distance2 points.(invA) points.(a)
      -. Utils.distance2 points.(b) points.(nextB),     -1, a
    else (* TRANSPORT *)
      let c = random_except n a b in
      let invC, nextC = sigmainv.(c), sigma.(c) in
         Utils.distance2 points.(a) points.(c)
      +. Utils.distance2 points.(c) points.(b)
      +. Utils.distance2 points.(invC) points.(nextC)
      -. Utils.distance2 points.(a) points.(b)
      -. Utils.distance2 points.(invC) points.(c)
      -. Utils.distance2 points.(c) points.(nextC),     c, a

  | -1 -> (* REVERSE*)
    sigma.(invA) <- b;
    sigma.(b) <- a;
    sigma.(a) <- nextB;

    sigmainv.(nextB) <- a;
    sigmainv.(a) <- b;
    sigmainv.(b) <- invA;
    0., -1, -1
    
  | c -> (* TRANSPORT *)
    let invC, nextC = sigmainv.(c), sigma.(c) in
    sigma.(a) <- c;
    sigma.(c) <- b;
    sigmainv.(b) <- c;
    sigmainv.(c) <- a;

    sigma.(invC) <- nextC;
    sigmainv.(nextC) <- invC;
    0., c, -1

(* Compute the distance of a circuit *)
let circuit_distance points sigma =
  let d = ref (Utils.distance2 points.(0) points.(sigma.(0))) in
  let i = ref sigma.(0) in
  while !i <> 0 do
    d := Utils.distance2 points.(!i) points.(sigma.(!i)) +. !d;
    i := sigma.(!i);
  done;
  !d

(* Simulated annealing algorithm *)
let annealing points h =
  let n = Array.length points in
  let invT = ref 0. in
  let (_, sigma, sigmainv) = basic_permutation n in
  let f = ref (circuit_distance points sigma) in

  let changes = ref n in

  while !changes > 0 do
    changes := 0;
    (* Manipulating the inverse in order not to manipulate floats *)
    invT := !invT +. 1.;

    for _k = 0 to h * n do
      (* Printf.printf "%d/%d\n" k (int_of_float (ceil threshold)); *)
      let delta, transformation, a = permute points (n, sigma, sigmainv) in
      let p = exp (-.delta *. !invT) in

      (* Metropolis rule *)
      if delta < 0. || Random.float 1. < p then (
        incr changes;
        let _, _, _ = permute ~transformation ~a points (n, sigma, sigmainv) in
        f := !f +. delta
      )
    done;
  done;
  sigma

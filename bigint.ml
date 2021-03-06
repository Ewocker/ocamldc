(* $Id: bigint.ml,v 1.5 2014-11-11 15:06:24-08 - - $ *)

open Printf

module Bigint = struct

    type sign     = Pos | Neg
    type bigint   = Bigint of sign * int list
    let  radix    = 10
    let  radixlen =  1

    let car       = List.hd
    let cdr       = List.tl
    let len       = List.length
    let map       = List.map
    let reverse   = List.rev
    let strcat    = String.concat
    let strlen    = String.length
    let strsub    = String.sub
    let zero      = Bigint (Pos, [])

    (*Mackey*)
    let trimzeros list =
        let rec trimzeros' list' = match list' with
            | []       -> []
            | [0]      -> []
            | car::cdr ->
                let cdr' = trimzeros' cdr
                in  match car, cdr' with
                    | 0, [] -> []
                    | car, cdr' -> car::cdr'
        in trimzeros' list

    let rec del_zero inList = 
        if len inList = 0
        then inList
        else if car inList = '0'
        then del_zero (cdr inList)
        else inList

    let charlist_of_string str = 
        let last = strlen str - 1
        in  let rec charlist pos result =
            if pos < 0
            then del_zero result
            else charlist (pos - 1) (str.[pos] :: result)
        in  charlist last []

    let bigint_of_string str =
        let len = strlen str
        in  let to_intlist first =
                let substr = strsub str first (len - first) in
                let digit char = int_of_char char - int_of_char '0' in
                map digit (reverse (charlist_of_string substr))
            in  if   len = 0
                then zero
                else if   str.[0] = '_'
                     then Bigint (Neg, to_intlist 1)
                     else Bigint (Pos, to_intlist 0)

    let string_of_bigint (Bigint (sign, value)) =
        match value with
        | []    -> "0"
        | value -> let reversed = reverse value
                   in  strcat ""
                       ((if sign = Pos then "" else "-") ::
                        (map string_of_int reversed))


    let rec cmp_old' list1 list2 = 
         match (list1, list2) with 
         | list1, [] -> 1
         | [], list2 -> 0
         | car1::cdr1, car2::cdr2 ->
             if car1 > car2
             then 1
             else if car1 < car2
             then -1
             else cmp_old' cdr1 cdr2

    let cmp_old list1 list2 =
        let len1 = List.length list1 in
        let len2 = List.length list2 in
            if len1 > len2
            then 1
            else if len1 < len2
            then -1
            else cmp_old' list1 list2

    let rec cmp' list1 list2 = match (list1, list2) with
        | [], []                 ->  0
        | list1, []              ->  1
        | [], list2              -> -1
        | car1::cdr1, car2::cdr2 -> 
            let retval = cmp' cdr1 cdr2
            in if retval = 0 && car1 != car2
               then (if car1 > car2
                    then 1
                    else (if car1 < car2
                    then -1
                    else 0))
              else retval

    let cmp (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        if neg1 = neg2
        then cmp' value1 value2
        else if neg1 = Neg
            then -1
            else 1

    let rec add' list1 list2 carry = match (list1, list2, carry) with
        | list1, [], 0       -> list1
        | [], list2, 0       -> list2
        | list1, [], carry   -> add' list1 [carry] 0
        | [], list2, carry   -> add' [carry] list2 0
        | car1::cdr1, car2::cdr2, carry ->
          let sum = car1 + car2 + carry
          in  sum mod radix :: add' cdr1 cdr2 (sum / radix)

    let rec sub' list1 list2 carry = match (list1, list2, carry) with
        | list1, [], 0       -> list1
        | [], list2, 0       -> list2
        | list1, [], carry   -> sub' list1 [carry] 0
        | [], list2, carry   -> sub' [carry] list2 0
        | car1::cdr1, car2::cdr2, carry ->
          let diff = car1 - car2 - carry in
              if (diff < 0 && (diff mod radix <> 0))
              then (diff + radix) mod radix :: sub' cdr1 cdr2 ((-diff/radix)+1)
              else if (diff < 0 && (diff mod radix = 0))
              then 0 :: sub' cdr1 cdr2 (-diff/radix)
              else diff :: sub' cdr1 cdr2 0

    let add (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        if neg1 = neg2
        then Bigint (neg1, add' value1 value2 0)
        else if (neg1 = Pos && neg2 = Neg)
        then (
            if (cmp_old value1 value2) = 1
            then Bigint(neg1, sub' value1 value2 0)
            else Bigint(neg2, sub' value2 value1 0))
        else (
            if (cmp_old value1 value2) = 1
            then Bigint(Neg, sub' value1 value2 0)  
            else Bigint(Pos, sub' value2 value1 0))    

    let sub (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        if (neg1 = neg2 && neg1 = Pos)
        then (
            if (cmp_old value1 value2) = 1
            then Bigint(Pos, sub' value1 value2 0)
            else Bigint(Neg, sub' value2 value1 0))
        else if ((neg1 = neg2 && neg1 = Neg))
        then Bigint(Neg, add' value1 value2 0)
        else (
            if (cmp_old value1 value2) =1
            then Bigint(neg1, add' value1 value2 0)
            else Bigint(neg2, add' value1 value2 0))

(* Fail for large num    
    let rec mul' value1 value2 = 
        if (trimzeros value2) = [1]
        then value1
        else (add' value1 (mul' value1 (sub' value2 [1] 0)) 0)

    let mul (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        if neg1 = neg2
        then Bigint (Pos, mul' value1 value2)
        else Bigint (Neg, mul' value1 value2)
*)
    let double_bigint_list number =
        add' number number 0

    let rec mul' (multiplier, powerof2, multiplicand') =
        if (cmp' powerof2 multiplier) = 1
        then multiplier, []
        else let remainder, product =
            mul' (multiplier, double_bigint_list powerof2,
                              double_bigint_list multiplicand')
         in if (cmp' powerof2 remainder) = 1
            then remainder, product
            else (trimzeros(sub' remainder powerof2 0)),
                (add' product multiplicand' 0)

    let mul (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        let _, product =
            mul' (value1, [1], value2) in
                if neg1 = neg2
                then Bigint (Pos, product)
                else Bigint (Neg, product)

    let rec divrem' (dividend, powerof2, divisor') =
        if (cmp' divisor' dividend) = 1
        then [0], dividend
        else let quotient, remainder =
                 divrem' (dividend, double_bigint_list powerof2,
                                    double_bigint_list divisor')
             in  if (cmp' divisor' remainder) = 1
                then quotient, remainder
                else (add' quotient powerof2 0),
                      (trimzeros(sub' remainder divisor' 0))

    let divrem ((Bigint (neg1, value1)), (Bigint (neg2, value2))) =
        let quotient, remainder = divrem' (value1, [1], value2)
        in if neg1 = neg2
          then Bigint (Pos, quotient),Bigint (Pos, remainder)
          else Bigint (Neg, quotient),Bigint (Pos, remainder)

    let rem (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        let _, remainder = divrem ((Bigint (neg1, value1)),
                                  (Bigint (neg2, value2)))
        in remainder

    let div (Bigint (neg1, value1)) (Bigint (neg2, value2)) =
        let quotient, _ = divrem ((Bigint (neg1, value1)),
                                (Bigint (neg2, value2)))
        in quotient

    let pow = add

end


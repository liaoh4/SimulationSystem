globals [Supplies_available input-location input-dc-supplies input-delivery-trip transportcost consumption-rate consumption-time PODs-allocation-policy WAIT-TICKS TRACK-PERSON-ID num_shipment last-shipmentsize total_goods serving_size serving_time]

breed [people person]
people-own [PODlist start_moving_time mypod target steps goods arrticks waitticks lifeticks depticks depcost prevdepcost totaldepcost lastpod0 lastpod1 dis2target dead walkingcost servicetime]

breed [PODs POD]
PODs-own [travel_distance servicetime supplies_per_day mydc pod2dc goods expected_goods isalloctime isdummy idleticks population PODs-allocation-interval travel_time num_handout initialgoods trans_cost]

breed [DCs DC]
DCs-own [allocticks podset goods numpods numtrucks dummypod routelists isalloctime population DeliveryNo]

breed [trucks truck]
trucks-own [departure_time target mydc myroute targetid goods driving_time]
;; myroute [start_time number_of_stops stop 0 (dc#) goods stop 1 goods stop 2 goods ...]


to setxy_edges
    if xcor - min-pxcor < 2 [ set xcor xcor + 2]
    if max-pxcor - xcor < 2 [ set xcor xcor - 2]
    if ycor - min-pycor < 2 [ set ycor ycor + 2]
    if max-pycor - ycor < 2 [ set ycor ycor - 2]
end

to load-input-location
  ; We check to make sure the file exists first
  ifelse ( file-exists? "input-location.txt" )
  [
    ; We are saving the data into a list, so it only needs to be loaded once.
    set input-location []
    file-close
    ; This opens the file, so we can use it.
    file-open "input-location.txt"
    print file-at-end?
    ; read the headline of variable names
    print file-read-line
    ; Read in all the data in the file
    while [ not file-at-end? ]
    [
      ; file-read gives you variables.  In this case numbers.
      ; We store them in a double list (ex [ [agent_type who xcor ycor] [dc 1 1 9.9999] [pod 2 2 9.9999] ...
      ; Each iteration we append the next four-tuple to the current list

      if file-read = "" []
      set input-location sentence input-location (list (list file-read file-read file-read))
    ]

    user-message "File input-location.txt loading complete!"

    ; Done reading in patch information.  Close the file.
    file-close
  ]
  [ user-message "There is no input-location.txt file in current directory!" ]
end



to setup
  clear-all
  reset-ticks
  ask patches [set pcolor white]
  show date-and-time
  if load-input-location? [
    load-input-location
  ]

;; print the location information of PODs and DCs



  ;; default parameters
  set PODs-allocation-policy "continous" ;; it assumes that PODs hand out supplies only if the inventory isn't empty
  ;set Number_of_DCs 2

  set serving_size Demand_per_person / 10 * Available_supplies;; the number of supplies handed out to a person each time
  set serving_time 60 / Throughput_per_server ;; the duration of a person in the server
  set consumption-rate 1440 ;;the time that a full serving of goods is able to support a person for, this is for the residul effect
  set consumption-time consumption-rate * (serving_size / (Demand_per_person / 10)) ;; the time that a serving size of goods is able to sustain a person for
  set WAIT-TICKS 360
  ;set load-input-location? true

  ;; configure the parameters
  set people-next-stop "nearest"    ;; nearest or random
  ;set DC-allocation-strategy "Proportionally" ;;Proportionally or Equally
  set Supplies_available Available_supplies * Number_of_victims * Demand_per_person
  set total_goods Supplies_available

  show word "Serving size is " serving_size
  show word "Time that a serving size of supplies can support a person for is " consumption-time
  show word "Maximum waiting time of victims is "WAIT-TICKS
  show word "People walking strategy is: " people-next-stop
  show word "DC allocation policy is: " DC-allocation-strategy



  random-seed init-random-seed
  ;; create DCs
  set-default-shape DCs "square"
  let myid 0
  let num-cols floor sqrt 1
  let num-rows floor sqrt 1
  let horizontal-spacing (max-pxcor  / num-cols)
  let vertical-spacing (max-pycor  / num-rows)
  let min-xpos (min-pxcor  + horizontal-spacing / 2)
  let min-ypos (min-pycor  + vertical-spacing / 2)
  ;let min-xpos 0
  ;let min-ypos 0

  create-DCs Number_of_DCs
  [
    ifelse load-input-location? [
      foreach input-location [ the-tuple ->
        if who = first the-tuple [
          setxy item 1 the-tuple last the-tuple
        ]
      ]
    ][
      setxy 0 0


    ]
    set color red
    set size 8
    ;set label who
    set DeliveryNo 0

    set dummypod -1
  ]

  random-seed init-random-seed
  ;; create PODs
  set-default-shape PODs "circle"
  set myid 0
  set num-cols 1
  set num-rows 3
  set horizontal-spacing (max-pxcor  / num-cols)
  set vertical-spacing (max-pycor  / num-rows)
  set min-xpos (min-pxcor  + horizontal-spacing / 2)
  set min-ypos (min-pycor  + vertical-spacing / 2)
  ;set min-xpos 0
  ;set min-ypos 0
  create-PODs Number_of_PODs ;+ Number_of_DCs
  [
    ;; PODs and DCs are not on the same patch
    ifelse load-input-location? = true [
      foreach input-location [ the-tuple ->
        if who = first the-tuple [
          setxy item 1 the-tuple last the-tuple
        ]
      ]
    ]
    [
      ;;setxy random-xcor random-ycor
      ifelse myid >= (num-cols * num-rows)
      [setxy max-pxcor * 0.05 + random-float (max-pxcor * 0.9) max-pycor * 0.05 + random-float (max-pycor * 0.9)]
      [
      let row (floor (myid / num-cols))
      let col (myid mod num-cols)
      setxy (min-xpos + col * horizontal-spacing  )   (min-ypos + row * vertical-spacing )
      ]
      set myid myid + 1
    ]
    set color green
    set size 2
    ;set label who
    ifelse myid > Number_of_PODs
    [ set mydc one-of DCs with [dummypod = -1 ] ]
    [ set mydc min-one-of DCs [distance myself] ]

    set pod2dc distance mydc
    ;set goods 18750
    ask mydc [
      set numpods numpods + 1
      if dummypod = -1 and myid > Number_of_PODs[
        set dummypod myself
        ask myself [
          setxy [xcor] of mydc [ycor] of mydc
          set isdummy 1
          ;; excluding dummy POD
          ;set numpods numpods - 1
        ]
      ]
    ]
    set pod2dc distance mydc
    set travel_time 14400
  ]
  random-seed init-random-seed
  ;; create people

  set myid Number_of_PODs + Number_of_DCs
  set num-cols floor sqrt Number_of_victims
  set num-rows floor sqrt Number_of_victims
  set horizontal-spacing (max-pxcor  / num-cols)
  set vertical-spacing (max-pycor  / num-rows)
  set min-xpos (min-pxcor  + horizontal-spacing / 2)
  set min-ypos (min-pycor  + vertical-spacing / 2)


  create-people Number_of_victims [
    set walkingcost 0.25 ;; the formula of walking costs is 0.25 + 0.03 * walking time (hour)
    setxy random-xcor random-ycor
    set PODlist []
    set servicetime 0
    set PODlist fput min-one-of PODs [distance myself] PODlist ;; the first site being visited is the nearest POD
    ;set label who
    set shape "circle"
    set start_moving_time random 240 ;;moving within in 4 hours of the disaster
    set size 0.5
    set color blue
    ;set target min-one-of PODs [distance myself]
    with-local-randomness [ people_choose_next_stop ]
    set arrticks 0
    set waitticks WAIT-TICKS ; wait 60mins x 6 at each POD
  ]


  ;; track a single person with who number of TRACK-PERSON-ID

  set TRACK-PERSON-ID Number_of_PODs + Number_of_DCs + Number_of_DCs
  ask person TRACK-PERSON-ID [
    set size 0.5
    set color blue
    pen-down
    show(word "my start time is " start_moving_time "; my PODs list is " PODlist)
    set pen-size 2
  ]


  foreach sort PODs [ the-pod ->
      ask the-pod [
      set population count people with [target = the-pod]
      ;show(word "My population is " population "; My DC is " mydc)
      ;show(word "My xcor is " xcor " My ycor is " ycor)
      set travel_distance (distance mydc) * 0.1
      set goods 0
      set initialgoods goods
      if DC-allocation-strategy = "Proportionally" [
      set expected_goods population * Demand_per_person * Available_supplies
   ]
      if DC-allocation-strategy = "Equally" [
      set expected_goods Number_of_victims * Demand_per_person * Available_supplies / Number_of_PODs
   ]
      set supplies_per_day expected_goods / 10

      set trans_cost travel_distance * expected_goods * 0.05
      show(word "My expected goods is " expected_goods "; My supplies per day is " supplies_per_day "; Distance to my DC is " precision (pod2dc / 40) 3 " km; Transportation costs are " trans_cost)

    ]
  ]

 ;; create trucks

   random-seed init-random-seed
 foreach sort DCs [ the-dc ->
    set-default-shape trucks "truck"
    let truckid 1
    ;; create 1 truck for each POD including the dummy POD exactly at DC, if not enough, created on demand later
    create-trucks 10 * [numpods] of the-dc
    [
      setxy [xcor] of the-dc [ycor] of the-dc
      ;set color 5 + truckid * 10
      set truckid truckid + 1
      set size 5
      set mydc the-dc
      set departure_time 0
      if show-truck-route?
       [ pen-down
         set pen-size 2
       ]
      set target mydc
      face target
      hide-turtle
    ]

    ask the-dc [set population sum [population] of PODs with [mydc = the-dc]
      set numtrucks count trucks with [mydc = the-dc]
      show(word "My population is " population "; Number of my PODs " numpods "; Number of my trucks " numtrucks)
      set goods floor(population * Available_supplies * Demand_per_person) ; compute the available supplies
      set podset (PODs with [mydc = the-dc])
      show(word "The pods assigned to me are " [who] of PODs with [mydc = the-dc] "; My total available supplies are " goods)

    ]
  ]


;foreach sort people [ the-people ->
;    ask the-people[show(word "my start time is " start_moving_time "; my PODs list is " PODlist)]
;  ]



  reset-ticks

end

to people_choose_next_stop
  ;random-seed init-random-seed
   if people-next-stop = "nearest" [

    ifelse PODlist != []
      ;[set target item 0 sort-by [[c d] -> ([distance myself] of c < [distance myself] of d) or ([distance myself] of c = [distance myself] of d and [who] of c < [who] of d)] (PODs with [who != [lastpod0] of myself and distance myself > 0])]
      ;[set target item 0 sort-by [[c d] -> ([distance myself] of c < [distance myself] of d) or ([distance myself] of c = [distance myself] of d and [who] of c < [who] of d)] PODs]
       [with-local-randomness [set target item 0 sort-by [[c d] -> ([distance myself] of c < [distance myself] of d) or ([distance myself] of c = [distance myself] of d and [who] of c < [who] of d)] PODlist]]
      ; [with-local-randomness [set target min-one-of PODs with [who != [lastpod0] of myself and distance myself > 0] [distance myself]]]
       [with-local-randomness [set target min-one-of PODs with [who != [lastpod0] of myself and distance myself > 0] [distance myself]]
       set PODlist fput target PODlist]

    set lastpod0 lastpod1
    set lastpod1 [who]  of target
  ;  if who = TRACK-PERSON-ID [
  ;      show (word "pod0 " lastpod0 " pod1 " lastpod1 " target " target)
  ;  ]

   ]



   if people-next-stop = "random" [
     ;random-seed init-random-seed
     set target nobody
     ;set target one-of PODs with [who != [lastpod0] of myself and distance myself > 0]

     ;;random with radius constraints
     ;let radius 10
     ;while [ target = nobody] [
     ;   set target one-of PODs with [who != [lastpod0] of myself and distance myself > 0 and distance myself < radius ]
     ;   set radius radius + 1
     ;]
      ifelse PODlist != []
      [with-local-randomness [set target one-of PODlist]
      let nearestpod item 0 sort-by [[c d] -> ([distance myself] of c < [distance myself] of d) or ([distance myself] of c = [distance myself] of d and [who] of c < [who] of d)] PODlist
   ; if target != nearestpod
    ;[show(word "*****I choose random POD, not the nearest POD*****, the target is " target ", the nearest pod is" nearestpod)]
  ]
      [with-local-randomness [set target one-of PODs with [distance myself > 0]]
      set PODlist fput target PODlist]


    set lastpod0 lastpod1
    set lastpod1 [who] of target
   ; if who = TRACK-PERSON-ID [
   ;     show (word "pod0 " lastpod0 " pod1 " lastpod1 " target " target)
   ; ]
   ]

;   if people-next-stop = "nearest" [
;     let people2dc distance mydc
;     let peopledc mydc
;     set target min-one-of PODs with [distance peopledc < people2dc] [distance myself]
;     if target = nobody or distance mydc < distance target
;       [ set target mydc ]
;   ]
;   if people-next-stop = "random" [
;     let people2dc distance mydc
;     let peopledc mydc
;     set target one-of PODs with [distance peopledc < people2dc]
;     if target = nobody or distance mydc < distance target
;       [ set target mydc ]
;   ]

  face target
end

to PODs_choose_allocation_policy
   ;set isalloctime 0
   if PODs-allocation-policy = "continous" [
      set isalloctime 1
      set num_handout 0
   ]
   if PODs-allocation-policy = "fixed-interval" [
    ifelse population * serving_time / Servers_per_pod > PODs-allocation-interval + consumption-time
       [ show(word "first")
         set isalloctime 1
         set population initialgoods

    ]
       [
      show(word "second")
         if (ticks + consumption-time) mod (PODs-allocation-interval + consumption-time) = 0
             [
              show(word "start distribution again")
              set num_handout 0
              set isalloctime 1
             ]
          if num_handout = population * serving_size
             [
             show(word "stop distributing")
             set isalloctime 0
             set num_handout 0
             ;show(word "Everyone has a goods during this period, handout are " num_handout)
             ]
      ]
   ]
end



to go
  goDCs
  goPODs
  goPeople
  gotrucks
  stats
  ;if ticks mod 60 = 0 [stats]
  tick
  show(ticks)
  ;if ticks = 1 [print (word "total transportation costs are " precision (sum [trans_cost] of PODs) 3)]
  if ticks >= 240 * 60 [finalstats show date-and-time stop]
  ;;if ticks >= 6 [finalstats show date-and-time stop]
end

to stats
  let alldepcost sum [totaldepcost ] of people
  let allwalkcost sum [walkingcost ] of people
  ;print (word "person " TRACK-PERSON-ID " at ticks " ticks " accumulative walking distance is " precision ([steps ] of person TRACK-PERSON-ID) 3 " km")
  ;print (word "person " TRACK-PERSON-ID " at ticks " ticks " accumulative walking cost is $ " precision ([walkingcost ] of person TRACK-PERSON-ID) 3)
  ;print (word "person "  TRACK-PERSON-ID  " at ticks " ticks " current deprivation time is " precision (([depticks ] of person TRACK-PERSON-ID) / 60) 3 " h")
  ;print (word "person "  TRACK-PERSON-ID " at ticks " ticks " current deprivation cost is $ " precision ([depcost ] of person TRACK-PERSON-ID) 3)
  ;print (word "person "  TRACK-PERSON-ID " at ticks " ticks " accumulative deprivation cost is $ " precision ([totaldepcost ] of person TRACK-PERSON-ID) 3)

end

to finalstats
  let alldepcost sum [totaldepcost ] of people
  let allwalkcost sum [walkingcost ] of people
  let allunconsumedgoods sum [goods ] of PODs
  let alltrans_cost sum [trans_cost] of PODs
  print (word "ticks " ticks " final all unconsumed supplies at PODs are " allunconsumedgoods)
  print (word "ticks " ticks " final death toll " sum [dead ] of people)
  print (word "ticks " ticks " final all deprivation cost is $ " precision sum [totaldepcost ] of people 3)
  print (word "ticks " ticks " final all walking cost is $" precision allwalkcost 3)
  print (word "ticks " ticks " final all transportation cost is $ " precision alltrans_cost 3)

end

to goDCs
  ask DCs [
    ;set persons count people-here
    ;set persons count people at-points [ [0 0] ]

    set population count people with [distance myself = 0]

    set isalloctime 0
    set allocticks 1440
    ifelse ticks mod allocticks = 0
    [set isalloctime 1
     set DeliveryNo DeliveryNo + 1]
    [set isalloctime 0]

    if isalloctime = 1 and goods > 0 [
     ; show(word "Delivery epoch is " ticks)
      foreach sort podset [ the-pod ->
        let the-truck one-of trucks with [goods = 0 and distance myself = 0]
        ;show(word "Dispatch trucks #" [who] of the-truck " to pod #" [who] of the-pod)
        if the-truck != nobody [    ;; we can create on demand, but let's create unlimited in the begining for simplicity
             ask  the-truck [
               set color 10 + random 360
               set target the-pod
               face target
               set driving_time ceiling(distance target / (Driving_speed / 60 / 0.025)) ;; (Driving_speed / 60 / 0.025) is the distance a truck drives in a tick
               set departure_time ([DeliveryNo] of myself - 1) * 1440 + 60 * (Truck_arrive_time + 1) - random 120 - driving_time
               ;show(word "It takes " driving_time " minutes to reach the POD. The departure time is " departure_time)
               ;show-turtle
               set goods [supplies_per_day] of the-pod
               ;show(word "My target is " target "; My dc is " mydc "; My goods is " goods)
               ask myself [
                 ;;update the goods of the DC

              set goods goods - [goods] of the-truck
             ; show (word "Supplies available are " goods)

            ]
          ]
          ]
      ;;
      ]

    ]

    ]

end

to goPODs
  ask PODs [
    ;; based on patch or exact points?
    ;set persons count people-here
    ;set persons count people at-points [ [0 0] ]

    ;;set all servers awailable at the beginning of the simulation
    if ticks = 0 [set idleticks serving_time]
    ;;set the rule for the operation of servers
    set idleticks idleticks + 1
   ; show(word "Now, the number of victims at this POD is: " count people with [target = myself and distance myself = 0])

   ; if ticks = 100 [show(word "Now, the number of victims at this POD is: " count people with [target = turtle 5 and distance turtle 5 = 0])]

    ;; determine the allocation policy (assume continuously)
    PODs_choose_allocation_policy

    ;; hand out supplies when idleticks >= serving_time
    if goods > 0 and isalloctime = 1 and idleticks >= serving_time [
      ;; count people without supplies at this POD
      let people_zerogoods []
      set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]
      if  people_zerogoods = nobody [set people_zerogoods []]

      ;;check if waiting queue is empty and inventory is empty
      if length sort people_zerogoods != 0 and goods != 0[
         ;show (word "Previously, total  supplies are " goods "Previously, total people waiting for supplies is " count people_zerogoods)

         set idleticks 0
         random-seed init-random-seed

         ifelse count people_zerogoods >= Servers_per_pod and goods / serving_size >= Servers_per_pod
         [
          ;show(word "1 way: my goods are " goods "; people without supplies are" count people_zerogoods)
          let i Servers_per_pod

          while[i > 0][with-local-randomness[
            ;ask item 0 sort-by [ [a b] -> ([arrticks] of a < [arrticks] of b) or ([arrticks] of a = [arrticks] of b and [who] of a < [who] of b)] people_zerogoods [
             ask item 0 sort-by [ [a b] -> [arrticks] of a < [arrticks] of b ] people_zerogoods [
              ;show (word "The person " who " is going to receive goods on ticks " ticks " at " [who] of myself)
               set servicetime 1
               set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]]
            set i i - 1]]

          set goods goods - serving_size * Servers_per_pod

          set num_handout num_handout + serving_size * Servers_per_pod
         ; show(word "1 way: my goods are " goods "; my handout is "  Servers_per_pod)
         ]

        ;; if victims or goods are less than the number of servers

         [
          ;show(word "ticks " ticks " 2 way: my goods are " goods "; people without supplies are" count people_zerogoods)
          let k count people_zerogoods
          let q floor((goods / serving_size))
          let i min list k q
         ; show(word "ticks " ticks " people aa without goods are " people_zerogoods)
          while[i > 0][with-local-randomness[
            ;ask item 0 sort-by [ [a b] -> ([arrticks] of a < [arrticks] of b) or ([arrticks] of a = [arrticks] of b and [who] of a < [who] of b)] people_zerogoods [
            ask item 0 sort-by [ [a b] -> [arrticks] of a < [arrticks] of b ] people_zerogoods [
          ;    show (word "The person " who " is going to receive goods on ticks " ticks " at " [who] of myself)
               set servicetime 1
           ;   show(word "ticks " ticks " people 11 without goods are " item 0 sort people_zerogoods)
               set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]

            ]
            set i i - 1]]
          ;show(word "ticks " ticks " people 33 without goods are " people_zerogoods)
          ;show(word "2 way: my handout is "  min list k q)
          set goods goods - serving_size * min list k q
          set num_handout num_handout + serving_size * min list k q
          ;show(word "2 way: my goods are " goods)
         ]
      ]
      set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]

   ]

    ;if isdummy = 0 [
      ;set label persons
      ;; display the id of each POD
     ; set label who
    ;]
  ]
end

to goPeople

  ask people [
    ;ifelse show-deptime?
    ;[set label steps]

    ;[set label ""]
    ;;display labels
    ;set label steps


    ;;if depticks > 120 * 60 [show "person die" die]

    if depticks > 5 * 24 * 60 [
      set dead 1
      ;show(word "The victim dead is person " who " at ticks" ticks)
      set goods serving_size
      set depcost 1000000
      set totaldepcost prevdepcost + depcost
      stop]

    set lifeticks lifeticks + 1

    if servicetime >= 1 [set servicetime servicetime + 1]


    if servicetime > serving_time [
      set goods serving_size
      let itera 0
      let shareset []

      ;; the first way to reset seprivation time (consider the residual effect)
      ;ifelse depticks < consumption-rate
      ;  [set depticks max list 0 (depticks - consumption-time)]
      ;  [set depticks (consumption-rate - consumption-time)]

      ;; the second way to reset seprivation time (without residual effect)
      set depticks 0

      set lifeticks 1
      set waitticks waitticks - 1
      set servicetime 0
      ;show (word "ticks " ticks " person " who " gets a unit of supplies "  )

      ;; share information when supplies are available
      while [itera < Information_sharing_rate]
      [ask one-of people with [who != [who] of myself and member? who shareset = false]  ;;those who are already at the POD or on the road to the POD will ignore the information
        [set shareset fput who shareset
        ;show(word "My PODlist is " PODlist "; my target is " target)
        if member? [target] of myself PODlist = false [set PODlist fput [target] of myself PODlist]

        ; show(word "The new POD added is " [target] of myself " ;My PODlist is " PODlist)
        ]
      set itera itera + 1
      ;show (word "shares set is "shareset)
      ]

    ]


    ifelse goods = serving_size [
      if lifeticks <= consumption-time
        [set depticks depticks]
      if lifeticks = consumption-time + 1 [
        set goods 0
        ;if who = TRACK-PERSON-ID [ show(word "I have no goods at " ticks) ]
        set arrticks ticks
        set waitticks WAIT-TICKS

      ]
    ]
    [set depticks depticks + 1]

    ifelse depticks = 0
      [set depcost 0]
      [set depcost 0.2354 * exp(0.1129 * depticks / 60)]

      ifelse lifeticks = 1
      [ifelse ticks < 1
         [set prevdepcost 0]
         [set prevdepcost totaldepcost]
      ]
      [set totaldepcost prevdepcost + depcost]

    set dis2target distance target


    ;; countdown at POD
    if dis2target = 0 and waitticks >= 0 and goods = 0
    [ let itera 0 ;; this is used to control the circulation
      let shareset [] ;;shareset is set to avoid sharing information with the same person more than once
      if waitticks = 0 and servicetime = 0[
        ;show(word "My PODList is " PODlist "; I didn't get supplies, I'll leave, " target " is removed from my PODlist")
        set PODlist remove target PODlist ;; remove the present POD from the PODlist
        ;show(word "My PODList is " PODlist)
        ;; share information when supplies are unavailable
          while [itera < Information_sharing_rate]
        [ask one-of people with [who != [who] of myself and member? who shareset = false]
          [set shareset fput who shareset
          ;show(word "Iteration : " itera " ;My PODlist is " PODlist "; my target is " target)
       if member? [target] of myself PODlist = true and target != [target] of myself ;;those who are already at the POD or on the road to the POD will ignore the information
        [set PODlist remove [target] of myself PODlist]
            ;[show("I ignore the information")]
       ; show(word "The POD removed is " [target] of myself " ;My PODlist is " PODlist)
        ]
      set itera itera + 1
        ;show (word "shares set is "shareset)
        ]
      people_choose_next_stop ;; target of the people is changed
        ;show(word "My PODList is " PODlist)
          set waitticks WAIT-TICKS
      ]
      set waitticks waitticks - 1
    ]

      ;; set waitticks for the waiting at next POD


    ;; move towards target.  once the distance is less than 1,
    ;; use move-to to land exactly on the target.
    ;; note if target is not changed and distance target is zero, will stay at the same target
    ;; 0.025km/min 1.5km/hour
    if ticks >= start_moving_time
    [ifelse distance target < 1
      [
        if distance target > 0 [
          move-to target
          set walkingcost walkingcost + (0.03 / 60)
          ;set steps steps + distance target
          set steps steps + 0.025 ;;one step is 0.025km
        ]
      ]
      [ fd Walking_speed / 60 / 0.025 ;;fd 1 means moving 0.025km walking speed is 1.5km/h
        set steps steps + 0.025
        set walkingcost walkingcost + (0.03 / 60)
      ;; set arrticks
        if distance target < 1 and distance target > 0
      [; show(word "ticks " (ticks + 1) " person " who " arrives at the POD " [who] of target)
        set arrticks ticks + 1 ]
        if distance target = 0
      [ ;show(word "ticks " ticks " person " who " arrives at the POD " [who] of target)
        set arrticks ticks ]

      ]
    ]
  ]
end

to gotrucks
  ask trucks [
    hide-turtle
    set label goods

    if ticks >= departure_time and distance target = 0 and goods > 0
      [
        ;show(word "My target is " target ", distance to my target is " distance target)

        let unloadgoods 0
        set unloadgoods goods
        set goods 0
        ask turtle [who] of target
        [
            set goods goods + unloadgoods
         ; show(word "TICKS " ticks " Trucks " [who] of myself " arrives, my goods are " goods)
          ]

        move-to mydc
        set target mydc
        hide-turtle
    ]
    if ticks >= departure_time and ticks <= departure_time + driving_time
      [ifelse distance target < Driving_speed / 60 / 0.025
        [
          if distance target > 0 [
            move-to target
            ;set steps steps + distance target
          ]

        ]
        [ fd Driving_speed / 60 / 0.025
          ;set steps steps + 10
        ]
    ]

  ]
end

; Public Domain:
; To the extent possible under law, Uri Wilensky has waived all
; copyright and related or neighboring rights to this model.
@#$#@#$#@
GRAPHICS-WINDOW
327
10
1939
663
-1
-1
4.0
1
10
1
1
1
0
0
0
1
0
160
0
200
1
1
1
ticks
30.0

BUTTON
23
453
125
486
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
190
454
293
487
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

INPUTBOX
163
310
318
370
init-random-seed
2.0
1
0
Number

SWITCH
0
416
155
449
show-truck-route?
show-truck-route?
1
1
-1000

CHOOSER
0
370
155
415
people-next-stop
people-next-stop
"nearest" "random"
0

SWITCH
163
416
319
449
load-input-location?
load-input-location?
1
1
-1000

INPUTBOX
163
70
318
130
Available_supplies
0.25
1
0
Number

INPUTBOX
0
70
155
130
Number_of_victims
4000.0
1
0
Number

CHOOSER
163
370
318
415
DC-allocation-strategy
DC-allocation-strategy
"Proportionally" "Equally"
1

INPUTBOX
0
130
155
190
Demand_per_person
40.0
1
0
Number

INPUTBOX
0
190
155
250
Driving_speed
15.0
1
0
Number

INPUTBOX
163
129
318
189
Throughput_per_server
3.0
1
0
Number

INPUTBOX
0
10
155
70
Number_of_DCs
1.0
1
0
Number

INPUTBOX
163
10
318
70
Number_of_PODs
10.0
1
0
Number

INPUTBOX
0
250
155
310
Servers_per_pod
15.0
1
0
Number

INPUTBOX
163
189
318
249
Walking_speed
1.5
1
0
Number

INPUTBOX
0
310
155
370
Truck_arrive_time
3.0
1
0
Number

INPUTBOX
163
249
318
310
Information_sharing_rate
1.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

This code demonstrates how a person walk towards a distribution center (DC) a step at a time.

## HOW IT WORKS

The `people` breed has a variable called `target`, which holds the agent the person is moving towards.

The `face` command points the person towards the target.  `fd` moves the person.  `distance` measures the distance to the target.

When a person reaches their target, they pick a random new target.

<!-- 2008 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="exp1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>sum [totaldepcost] of people</metric>
    <metric>sum [walkingcost] of people</metric>
    <metric>sum [goods] of PODs</metric>
    <metric>sum [dead] of PODs</metric>
    <enumeratedValueSet variable="Number_of_victims">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Servers_per_pod">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Available_supplies">
      <value value="0.25"/>
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_PODs">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Information_sharing_rate">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="init-random-seed" first="1" step="2" last="19"/>    
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@


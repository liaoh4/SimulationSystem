globals [input-location input-dc-supplies input-delivery-trip truckcost transportcost number-of-people truck-speed consumption-rate consumption-time WAIT-TICKS TRACK-PERSON-ID num_shipment last-shipmentsize total-goods unit serving_time]

breed [people person]
people-own [mydc target steps goods arrticks waitticks lifeticks depticks depcost prevdepcost totaldepcost lastpod0 lastpod1 dis2target dead walkingcost servicetime]

breed [PODs POD]
PODs-own [mydc pod2dc persons goods isalloctime isdummy idleticks population PODs-allocation-interval travel_time num_handout]

breed [DCs DC]
DCs-own [persons goods numpods dummypod routelists isalloctime]

breed [trucks truck]
trucks-own [target mydc myroute targetid goods]
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

to load-dc-supply
  ; We check to make sure the file exists first
  ifelse ( file-exists? "input-dc-supplies.txt" )
  [
    ; We are saving the data into a list, so it only needs to be loaded once.
    set input-dc-supplies []

    ; This opens the file, so we can use it.
    file-open "input-dc-supplies.txt"

    ; read the headline of variable names
    print file-read-line

    ; Read in all the data in the file
    while [ not file-at-end? ]
    [
      ; file-read gives you variables.  In this case numbers.
      ; We store them in a double list (ex [ [agent_type who xcor ycor] [dc 1 1 9.9999] [pod 2 2 9.9999] ...
      ; Each iteration we append the next four-tuple to the current list
      let the-tuple []
      repeat number-of-DCs + 1 [ set the-tuple lput file-read the-tuple]
      set input-dc-supplies lput  the-tuple input-dc-supplies
      show the-tuple
    ]

    user-message "File input-dc-supplies.txt loading complete!"

    ; Done reading in patch information.  Close the file.
    file-close
  ]
  [ user-message "There is no input-dc-supplies.txt file in current directory!" ]
end

to load-delivery-trip
  ; We check to make sure the file exists first
  ifelse ( file-exists? "delivery trip.txt" )
  [
    ; We are saving the data into a list, so it only needs to be loaded once.
    set input-delivery-trip []

    ; This opens the file, so we can use it.
    file-open "delivery trip.txt"

    ; read the headline of variable names
    print file-read-line

    ; Read in all the data in the file
    while [ not file-at-end? ]
    [
      ; file-read gives you variables.  In this case numbers.
      ; We store them in a double list (ex [ [agent_type who xcor ycor] [dc 1 1 9.9999] [pod 2 2 9.9999] ...
      ; Each iteration we append the next four-tuple to the current list
      let the-tuple []
      repeat 3 [ set the-tuple lput file-read the-tuple] ;; start time,  dc, goods
      let num_stops file-read
      set the-tuple insert-item 1 the-tuple num_stops;; num_stops
      repeat num_stops [ set the-tuple lput file-read the-tuple]
      repeat num_stops [ set the-tuple lput file-read the-tuple]

      set input-delivery-trip lput the-tuple input-delivery-trip
      show the-tuple
    ]

    user-message "File delivery trip.txt loading complete!"

    ; Done reading in patch information.  Close the file.
    file-close
  ]
  [ user-message "There is no delivery trip.txt file in current directory!" ]
end

to setup
  clear-all
  reset-ticks

  show date-and-time
  if load-input-location? [
    load-input-location
  ]

  if load-dc-supplies? = true [
    load-dc-supply
  ]

  if load-delivery-trip? [
    load-delivery-trip
  ]

  if file-exists? "output-location.txt" [
    file-open "output-location.txt"
    file-close
    file-delete "output-location.txt"
  ]
  file-open "output-location.txt"
  file-print (word "agent " "who " "xcor " "ycor")
  file-close

  if file-exists? "pod-dc.txt" [
    file-open "pod-dc.txt"
    file-close
    file-delete "pod-dc.txt"
  ]
  file-open "pod-dc.txt"
  file-print (word "POD " "DC " "POD2DC" )
  file-close

  ;; default parameters
  set PODs-allocation-policy "fixed-interval" ;; continous or fixed-interval
  set DCs-allocation-policy "fixed-interval"
  set truck-speed 10
  set init-random-seed 4
  set unit 1
  set serving_time 1

  ;;set DCs-allocation-interval 360
  set consumption-rate 480
  set consumption-time 480 * unit
  set number-of-people 108000
  set WAIT-TICKS 14400
  set show-truck-route? false
  set load-dc-supplies? false
  set load-delivery-trip? false
  set load-input-location? true

  ;; configure the parameters
  set people-next-stop "nearest"    ;; nearest or random

  ;;start setting
  ;set server 5
  set total-goods total-supplies

  set num_shipment ceiling (total-supplies / (number-of-PODs * truck-capacity))
  show (word "Number of deliveries to each POD " num_shipment " Truck capacity " truck-capacity)
  ;set POD-SUPPLIES floor (total-supplies / (number-of-PODs  * num_shipment))
  set POD-SUPPLIES truck-capacity
  set last-shipmentsize floor (total-supplies / number-of-PODs - (num_shipment - 1) * truck-capacity)
  show word "Normal shipment size " POD-SUPPLIES
  show word "Last shipment size " last-shipmentsize
  set DCs-allocation-interval floor (14400 / num_shipment)
  show word "DCs allocation interval " DCs-allocation-interval
  show word "People walking strategy " people-next-stop
  show word "PODs allocation policy " PODs-allocation-policy


  random-seed init-random-seed
  ;; create DCs
  set-default-shape DCs "circle"
  let myid 0
  let num-cols floor sqrt number-of-DCs
  let num-rows floor sqrt number-of-DCs
  let horizontal-spacing (max-pxcor  / num-cols)
  let vertical-spacing (max-pycor  / num-rows)
  let min-xpos (min-pxcor  + horizontal-spacing / 2)
  let min-ypos (min-pycor  + vertical-spacing / 2)
  ;let min-xpos 0
  ;let min-ypos 0

  create-DCs number-of-DCs
  [
    ifelse load-input-location? [
      foreach input-location [ the-tuple ->
        if who = first the-tuple [
          setxy item 1 the-tuple last the-tuple
        ]
      ]
    ][
      ifelse myid >= (num-cols * num-rows)
      [
        setxy random-xcor random-ycor
        ;setxy max-pxcor * 0.05 + random-float (max-pxcor * 0.9) max-pycor * 0.05 + random-float (max-pycor * 0.9)
      ]
      [
      ;;setxy random-xcor random-ycor
      ;setxy random-xcor myid * max-pycor / number-of-DCs + random-float max-pycor / number-of-DCs
      let row (floor (myid / num-cols))
      let col (myid mod num-cols)

      ;setxy (min-xpos + col * horizontal-spacing + random-float horizontal-spacing )   (min-ypos + row * vertical-spacing + random-float vertical-spacing )
      setxy (min-xpos + col * horizontal-spacing )   (min-ypos + row * vertical-spacing )

        ;show vertical-spacing
      ;show row
      ]
      set myid myid + 1
      ;setxy_edges

    ]
    set color red
    set size 1.5
    ;set persons 0
    ;; random goods at each DC
    ;set goods 10000 + random 10000
    ;; equal goods at each DC0
    ;set goods number-of-people * 10

   ; if load-dc-supplies? = false [
   ;   set goods total-supplies
   ; ]
    set dummypod -1
    file-open "output-location.txt"
    file-write "dc"
    file-print (word " " who " " xcor " " ycor)
    file-close
  ]

  random-seed init-random-seed
  ;; create PODs
  set-default-shape PODs "house"
  set myid 0
  set num-cols floor sqrt number-of-PODs
  set num-rows floor sqrt number-of-PODs
  set horizontal-spacing (max-pxcor  / num-cols)
  set vertical-spacing (max-pycor  / num-rows)
  set min-xpos (min-pxcor  + horizontal-spacing / 2)
  set min-ypos (min-pycor  + vertical-spacing / 2)
  ;set min-xpos 0
  ;set min-ypos 0
  create-PODs number-of-PODs ;+ number-of-DCs
  [
    ;; PODs and DCs are not on the same patch
    ifelse load-input-location? = true [
      foreach input-location [ the-tuple ->
        if who = first the-tuple [
          setxy item 1 the-tuple last the-tuple
        ]
      ]
    ][
      ;;setxy random-xcor random-ycor
      ifelse myid >= (num-cols * num-rows)
      [setxy max-pxcor * 0.05 + random-float (max-pxcor * 0.9) max-pycor * 0.05 + random-float (max-pycor * 0.9)]
      [
      let row (floor (myid / num-cols))
      let col (myid mod num-cols)


      ;setxy (min-xpos + col * horizontal-spacing + random-float horizontal-spacing )   (min-ypos + row * vertical-spacing + random-float vertical-spacing )
      setxy (min-xpos + col * horizontal-spacing  )   (min-ypos + row * vertical-spacing )

        ;setxy (min-xpos + col * horizontal-spacing - random-float horizontal-spacing / 2)   (min-ypos + row * vertical-spacing - random-float vertical-spacing / 2)
      ;show row
      ;show col
      ;show myid
      ]
      set myid myid + 1

      ;setxy_edges
    ]
    set color green
    set size 1.5
    set persons 0
    ifelse myid > number-of-PODs
    [ set mydc one-of DCs with [dummypod = -1 ] ]
    [ set mydc min-one-of DCs [distance myself] ]

    set pod2dc distance mydc
    ;set goods 18750
    ask mydc [
      set numpods numpods + 1
      if dummypod = -1 and myid > number-of-PODs[
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
    file-open "output-location.txt"
    file-write "pod"
    file-print (word " " who " " xcor " " ycor)
    file-close
    file-open "pod-dc.txt"
    file-print (word who " " [who] of mydc " " pod2dc)
    file-close
  ]
  file-close

  random-seed init-random-seed
  ;; create people

  set myid number-of-PODs + number-of-DCs
  set num-cols floor sqrt number-of-people
  set num-rows floor sqrt number-of-people
  set horizontal-spacing (max-pxcor  / num-cols)
  set vertical-spacing (max-pycor  / num-rows)
  set min-xpos (min-pxcor  + horizontal-spacing / 2)
  set min-ypos (min-pycor  + vertical-spacing / 2)


  create-people number-of-people [

    set walkingcost 0.25
    setxy random-xcor random-ycor
    ;set shape "person"
    set size 1
    set color blue
    ;set target one-of PODs

    set mydc min-one-of DCs [distance myself]
    with-local-randomness [ people_choose_next_stop ]

    set arrticks 0
    set waitticks WAIT-TICKS ; wait 60mins x 6 at each POD
  ]

  ;; track a single person with who number of TRACK-PERSON-ID
  set TRACK-PERSON-ID number-of-PODs + number-of-DCs + number-of-DCs
  ask person TRACK-PERSON-ID [
    set size 3
    set color pink
    pen-down
    set pen-size 2
  ]

  random-seed init-random-seed
  ifelse load-delivery-trip? = TRUE
  [ foreach sort DCs [ the-dc ->
      ask the-dc [set routelists input-delivery-trip]
    ]
  ]
  [
    ;; create routes for each DC
    foreach sort DCs [ the-dc ->
      let id 0
      let route (list 0 truck-stops [who] of the-dc 0) ;start from dc
      let podid 0
      let podsize length sort PODs with [ mydc = the-dc ]
      ;;sort based on who number
      ;foreach sort PODs with [ mydc = the-dc ] [ the-pod ->
      ;;sort based on distance to DC

      foreach sort-by [ [a b] -> [distance mydc] of a < [distance mydc] of b ] PODs with [ mydc = the-dc] [ the-pod ->
        set podid podid + 1
        set route lput [who] of the-pod route
        set route lput 0 route ;; supplies for this stop
        set id id + 1
        if id = truck-stops or podid = podsize or [isdummy] of the-pod = 1 [
          ask the-dc [
            ifelse routelists = 0
              [ set routelists (list route) ]
              [set routelists lput route routelists]
          ]
          set id 0
          set route (list 0 truck-stops [who] of the-dc 0) ; start from dc
        ]
      ]
    ]
  ]

 foreach sort PODs [ the-pod ->
      ask the-pod [set population count people with [target = the-pod]
      show(word "My population is " population)
      set PODs-allocation-interval floor(population * 30 / POD-SUPPLIES * unit * 480)
      show(word "My allocation interval is " PODs-allocation-interval)
    ]
  ]


  random-seed init-random-seed
  ;; create trucks
  foreach sort DCs [ the-dc ->
    set-default-shape trucks "truck"
    let truckid 1
    ;; create 1 truck for each POD including the dummy POD exactly at DC, if not enough, created on demand later
    create-trucks [10000 * numpods] of the-dc
    [
      setxy [xcor] of the-dc [ycor] of the-dc
      ;set color 5 + truckid * 10
      set truckid truckid + 1
      set size 2
      if show-truck-route?
       [ pen-down
         set pen-size 3
       ]
      set target the-dc
      face target
      hide-turtle
    ]

    if load-dc-supplies? = false [
      ask the-dc [
        ifelse total-goods > floor(total-supplies / number-of-PODs) * numpods + number-of-PODs
        [set goods floor(total-supplies / number-of-PODs) * numpods]
        [set goods total-goods]
        show numpods
        show goods
        ;set total-goods total-goods - goods
        ;show(word " total goods here is " total-goods)

      ]

    ]
  ]

  if file-exists? "deprivation.txt" [
    file-close
    file-delete "deprivation.txt"
  ]
  file-open "deprivation.txt"

  reset-ticks

end

to people_choose_next_stop
   random-seed init-random-seed
   if people-next-stop = "nearest" [
    ifelse ticks > 0
      ;[set target item 0 sort-by [[c d] -> ([distance myself] of c < [distance myself] of d) or ([distance myself] of c = [distance myself] of d and [who] of c < [who] of d)] (PODs with [who != [lastpod0] of myself and distance myself > 0])]
      ;[set target item 0 sort-by [[c d] -> ([distance myself] of c < [distance myself] of d) or ([distance myself] of c = [distance myself] of d and [who] of c < [who] of d)] PODs]
       [with-local-randomness [set target min-one-of PODs with [who != [lastpod0] of myself and distance myself > 0] [distance myself]]]
       [with-local-randomness [set target min-one-of PODs [distance myself]]]

    set lastpod0 lastpod1
    set lastpod1 [who]  of target
  ;  if who = TRACK-PERSON-ID [
  ;      show (word "pod0 " lastpod0 " pod1 " lastpod1 " target " target)
  ;  ]

   ]
   if people-next-stop = "random" [
     set target nobody

     set target one-of PODs with [who != [lastpod0] of myself and distance myself > 0]

     ;;random with radius constraints
     ;let radius 10
     ;while [ target = nobody] [
     ;   set target one-of PODs with [who != [lastpod0] of myself and distance myself > 0 and distance myself < radius ]
     ;   set radius radius + 1
     ;]


    set lastpod0 lastpod1
    set lastpod1 [who]  of target
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
   ]
   if PODs-allocation-policy = "fixed-interval" [
    ifelse population * serving_time / server > PODs-allocation-interval
       [set isalloctime 1
        set population POD-SUPPLIES / unit]
       [
          if (ticks - travel_time) mod PODs-allocation-interval = 0
             [
              set num_handout 0
              set isalloctime 1
             ]
          if num_handout = population * unit
             [
             set isalloctime 0
             set num_handout 0
             show (word "Everyone has a goods during this period, handout are " num_handout)
             ]
      ]
   ]
end

to DCs_choose_allocation_policy
   set isalloctime 0
   if DCs-allocation-policy = "continous" [
      set isalloctime 1
   ]
   if DCs-allocation-policy = "fixed-interval" [
      ifelse DCs-allocation-interval = 0 [
         set isalloctime 1
      ]
      [ ifelse ticks mod DCs-allocation-interval = 0 [
           set isalloctime 1
        ]
        [
           set isalloctime 0
        ]
      ]
   ]
   ;if load-delivery-trip? [ set isalloctime 1]
end

to go
  goDCs
  gotrucks
  goPeople
  goPODs
  show ticks
  if ticks mod 60 = 0 [stats]
  tick
  if ticks >= 240 * 60 [finalstats show date-and-time stop]
  ;;if ticks >= 6 [finalstats show date-and-time stop]
end

to stats
  let alldepcost sum [totaldepcost ] of people
  let allwalkcost sum [walkingcost ] of people
  print (word "person " TRACK-PERSON-ID " at ticks " ticks " accumulative walking distance is " precision ([steps ] of person TRACK-PERSON-ID) 3 " km")
  print (word "person " TRACK-PERSON-ID " at ticks " ticks " accumulative walking cost is $ " precision ([walkingcost ] of person TRACK-PERSON-ID) 3)
  print (word "person "  TRACK-PERSON-ID  " at ticks " ticks " current deprivation time is " precision (([depticks ] of person TRACK-PERSON-ID) / 60) 3 " h")
  print (word "person "  TRACK-PERSON-ID " at ticks " ticks " current deprivation cost is $ " precision ([depcost ] of person TRACK-PERSON-ID) 3)
  print (word "person "  TRACK-PERSON-ID " at ticks " ticks " accumulative deprivation cost is $ " precision ([totaldepcost ] of person TRACK-PERSON-ID) 3)
  ;print (word "ticks " ticks " all_dep_time_mean " mean [depticks ] of people)
  ;print (word "ticks " ticks " all_dep_cost_mean " mean [depcost ] of people)
  print (word "ticks " ticks " death toll is " sum [dead ] of people)
  print (word "ticks " ticks " all deprivation cost is $ " precision alldepcost 3)
  print (word "ticks " ticks " all walking cost is $ " precision allwalkcost 3)
  print (word "ticks " ticks " all transportation cost is $ " precision transportcost 3)
  print (word "ticks " ticks " all human cost is $ " precision (alldepcost + allwalkcost) 3)
  print (word "ticks " ticks " all social cost is $ " precision (transportcost + allwalkcost + alldepcost) 3)
  print (word "ticks " ticks " all current deprivation cost is $ " precision (sum [depcost] of people) 3)

end

to finalstats
  let alldepcost sum [totaldepcost ] of people
  let allwalkcost sum [walkingcost ] of people
  let allunconsumedgoods sum [goods ] of PODs
  ;print (word "ticks " ticks " final_track_dep_time " [depticks ] of person TRACK-PERSON-ID)
  ;print (word "ticks " ticks " final_track_dep_cost " [depcost ] of person TRACK-PERSON-ID)
  ;print (word "ticks " ticks " final_track_dep_cost_sum " [totaldepcost ] of person TRACK-PERSON-ID)
  ;print (word "ticks " ticks " final_all_dep_time_mean " mean [depticks ] of people " std " standard-deviation [depticks ] of people " max " max [depticks] of people " min " min [depticks] of people)
  ;print (word "ticks " ticks " final_all_dep cost_mean " mean [depcost ] of people " std " standard-deviation [depcost ] of people " max " max [depcost] of people " min " min [depcost] of people)
  print (word "ticks " ticks " final all unconsumed supplies at PODs " allunconsumedgoods " units")
  print (word "ticks " ticks " final death toll " sum [dead ] of people)
  ;print (word "ticks " ticks " final all deprivation cost " sum [totaldepcost ] of people " std " standard-deviation [totaldepcost ] of people " max " max [totaldepcost] of people " min " min [totaldepcost] of people)
  print (word "ticks " ticks " final all deprivation cost is $ " precision sum [totaldepcost ] of people 3)
  print (word "ticks " ticks " final all walking cost is $" precision allwalkcost 3)
  print (word "ticks " ticks " final all transportation cost is $ " precision transportcost 3)
  print (word "ticks " ticks " final all human cost is $ " precision (alldepcost + allwalkcost) 3)
  print (word "ticks " ticks " final all social cost is $ " precision (transportcost + allwalkcost + alldepcost) 3)

end

to goDCs
  ask DCs [
    ;set persons count people-here
    ;set persons count people at-points [ [0 0] ]

    ;;set persons count people with [distance myself = 0]

    if load-dc-supplies? = true [
      foreach input-dc-supplies [ the-tuple ->
        if (ticks + 1) = first the-tuple [
          show the-tuple
          set goods goods + item (who + 1) the-tuple
        ]
      ]
      ;set input-dc-supplies remove-item 0 input-dc-supplies
    ]

    ;show goods

    DCs_choose_allocation_policy

    let routeid 0
    if isalloctime = 1 [

      if routelists = 0 [
         show "empty routelists"
         set routelists []
      ]

      foreach routelists [ the-route ->
        let ismyticks 1
        if load-delivery-trip? and ( (ticks + 1) != (first the-route) or who != (item 2 the-route) )
          [set ismyticks 0]
        if ismyticks = 1 and (goods > 0) and (goods >= item 3 the-route) [ ;; sufficient goods for this trip
          set routeid routeid + 1
          ;show routeid
          ;show goods
          let the-truck one-of trucks with [goods = 0 and distance myself = 0]
          if the-truck != nobody [    ;; we can create on demand, but let's create unlimited in the begining for simplicity
             let loadgoods 0
             ask  the-truck [
               set color 5 + routeid * 10
               set myroute the-route
               set targetid 1
               set target turtle item ((targetid + 1) * 2) myroute   ;; 0: start_time, 1: num_stops, 2: stop 0, 3: goods, 4: stop1, 5: goods
               face target

               show-turtle
               set mydc myself
               ifelse load-delivery-trip?
                 [set loadgoods item 3 myroute]
                 [ifelse ticks < DCs-allocation-interval * (num_shipment - 1)
                    [set loadgoods POD-SUPPLIES * item 1 the-route]
                    [ifelse [goods] of mydc - last-shipmentsize < number-of-PODs
                      [set loadgoods max list [goods] of mydc last-shipmentsize * item 1 the-route]
                      [set loadgoods last-shipmentsize * item 1 the-route]
                    ]

                ]	
               ;show (word ([goods] of myself) " " loadgoods " " POD-SUPPLIES " " length myroute)
               set goods loadgoods
               set transportcost transportcost + distance target * 0.1 * goods * 0.05
;               ask myself [
;                 ;show (word goods " " loadgoods)
;                 set goods goods - loadgoods
;               ]
             ]
            ;show goods
            ;show loadgoods
            set goods goods - loadgoods
          ]
        ]
      ]
    ]

    ;set size 1 + persons * 0.01
    ;; display the number of persons
    ;;set label (word "p" persons " s"  (goods / 1000) "K")
    ;set label who
  ]
end

to goPODs
  ask PODs [
    ;; based on patch or exact points?
    ;set persons count people-here
    ;set persons count people at-points [ [0 0] ]

    ;;set persons count people with [distance myself = 0]
    if ticks = 0 [set idleticks serving_time]
    ;set size 1 + persons * 0.01
    set idleticks idleticks + 1
    PODs_choose_allocation_policy
;    show(word "ticks " ticks " goods " goods " idleticks " idleticks " isalloctime " isalloctime)


    if goods > 0 and isalloctime = 1 and idleticks >= serving_time [

      let people_zerogoods []
      set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]
      if  people_zerogoods = nobody
      [
        ;show "people_zerogoods"
        set people_zerogoods []
      ]

      if length sort people_zerogoods != 0 and goods != 0[
        ; show (word "Previously, total  supplies are " goods)
        ; show (word "Previously, total people waiting for supplies is " count people_zerogoods)
         set idleticks 0
         random-seed init-random-seed
         ifelse count people_zerogoods >= server and goods / unit >= server
         [
          let i min list server (population - num_handout / unit)
          while[i > 0][with-local-randomness[
            ;ask item 0 sort-by [ [a b] -> ([arrticks] of a < [arrticks] of b) or ([arrticks] of a = [arrticks] of b and [who] of a < [who] of b)] people_zerogoods [
             ask item 0 sort-by [ [a b] -> [arrticks] of a < [arrticks] of b ] people_zerogoods [
               ;if who = TRACK-PERSON-ID [ show (word "receives goods on ticks " ticks " at " target) ]
               set servicetime 1
               set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]]
            set i i - 1]]
          set goods goods - unit * (min list server (population - num_handout / unit))
          set num_handout num_handout + unit * (min list server (population - num_handout / unit))
          if num_handout = population * unit
            [show (word "Everyone has a goods during this period, handout are " num_handout)]
         ]

         [let k count people_zerogoods
          let i min (list k (goods / unit) (population - num_handout / unit))
          while[i > 0][with-local-randomness[
            ;ask item 0 sort-by [ [a b] -> ([arrticks] of a < [arrticks] of b) or ([arrticks] of a = [arrticks] of b and [who] of a < [who] of b)] people_zerogoods [
            ask item 0 sort-by [ [a b] -> [arrticks] of a < [arrticks] of b ] people_zerogoods [
               ;if who = TRACK-PERSON-ID [ show (word "receives goods on ticks " ticks " at " target) ]
               set servicetime 1
               set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]]
            set i i - 1]]
                  set goods goods - unit * (min (list k (goods / unit) (population - num_handout / unit)))
         set num_handout num_handout + unit * min (list k (goods / unit) (population - num_handout / unit))
         if num_handout = population * unit
           [show (word "Everyone has a goods during this period, handout are " num_handout)]
         ]


      ;show (word "Now, total people waiting for supplies is " count people_zerogoods)
      ;show (word "Now, total  supplies are " goods)
      ;show (word "Now, population receiving supplies are " num_handout)
      ]
      set people_zerogoods people with [ goods = 0 and distance myself = 0 and servicetime = 0]

   ]
    ;; display the number of persons
    if isdummy = 0 [
      ;set label persons
      ;;set label (word "p" persons " s"  (goods / 1000) "K")
      ;; display the id of each POD
      ;set label who
    ]
  ]
end

to goPeople

  ask people [
    ;ifelse show-deptime?
    ;[set label steps]
    ;[set label who]
    ;[set label ""]
    ;;display labels
    ;set label steps


    ;;if depticks > 120 * 60 [show "person die" die]

    if depticks > 5 * 24 * 60 [
      set dead 1
      set goods unit
      set depcost 1000000
      set totaldepcost prevdepcost + depcost
      stop]

    set lifeticks lifeticks + 1

    if servicetime >= 1 [set servicetime servicetime + 1]
    if servicetime > serving_time [
      set goods unit
      ifelse depticks < consumption-rate
        [set depticks max list 0 (depticks - consumption-time)]
        [set depticks (consumption-rate - consumption-time)]
      set lifeticks 1
      set waitticks waitticks - 1
     ; show (word "ticks " ticks " person " who " gets a unit of supplies at " target )
      set servicetime 0
    ]

    ifelse goods = unit [
      if lifeticks <= consumption-time
        [set depticks depticks]
      if lifeticks = consumption-time + 1 [
        set goods 0
        set arrticks ticks
        set waitticks WAIT-TICKS
         ;if who = TRACK-PERSON-ID [ show (word "completely consumed on ticks " ticks " at " target " lifetick " lifeticks) ]
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
    if dis2target = 0 and waitticks > 0 and goods = 0
    [
      if waitticks = 1 and servicetime = 0[
          people_choose_next_stop
          set waitticks WAIT-TICKS
      ]
      set waitticks waitticks - 1
    ]

      ;; set waitticks for the waiting at next POD


    ;; move towards target.  once the distance is less than 1,
    ;; use move-to to land exactly on the target.
    ;; note if target is not changed and distance target is zero, will stay at the same target
    ;; assuming 0.7m/sec 42m/min 2.5km/hour
    ifelse distance target < 1
      [
        if distance target > 0 [
          move-to target
          set walkingcost walkingcost + (0.03 / 60)
          ;set steps steps + distance target
          set steps steps + 0.025
        ]

      ]
      [ fd 1
        set steps steps + 0.025
        set walkingcost walkingcost + (0.03 / 60)
      ;; set arrticks
        if distance target < 1 and distance target > 0
      [; show(word "ticks " (ticks + 1) " person " who " arrives at the POD " [who] of target)
        set arrticks ticks + 1 ]
        if distance target = 0
      [; show(word "ticks " ticks " person " who " arrives at the POD " [who] of target)
        set arrticks ticks ]

      ]
  ]
end

to gotrucks
  ask trucks [
    ;show-turtle
    ;;set label goods
  if (targetid > 0 and goods > 0) or targetid = 0 [
   ;   set truckcost  truckcost + distance target * 0.1 * goods * 0.05
      move-to target
    ]

    if distance target = 0
      [
        ifelse targetid > 0
        [
          let unloadgoods 0
          ifelse load-delivery-trip?
            [set unloadgoods item ((targetid + 1) * 2 + 1)  myroute]
            [set unloadgoods min list goods POD-SUPPLIES]
          set goods goods - unloadgoods
          ask turtle item ((targetid + 1) * 2) myroute
          [
            set goods goods + unloadgoods
            set travel_time ticks
            show (word "One delivery arriving at ticks " ticks " arriving goods is " unloadgoods ",  now inventory is " goods)
            show (word "Travel time is " travel_time)
          ]
          set targetid targetid + 1
          if (targetid + 1) * 2 >= length myroute
            [set targetid 0]
          set target turtle item ((targetid + 1) * 2) myroute
          face target
        ]
        [hide-turtle]
    ]

  ; if (targetid > 0 and goods > 0) or targetid = 0 [
     ; ifelse distance target < truck-speed * 0.25
     ;   [  if distance target > 0 [ move-to target ] ]
    ;    [ fd truck-speed * 0.25 ]
   ; ]
  ]
end

; Public Domain:
; To the extent possible under law, Uri Wilensky has waived all
; copyright and related or neighboring rights to this model.
@#$#@#$#@
GRAPHICS-WINDOW
353
10
865
523
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
144
0
144
1
1
1
ticks
30.0

BUTTON
0
10
85
43
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
92
10
177
43
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

SLIDER
1
97
173
130
number-of-PODs
number-of-PODs
0
100
4.0
10
1
NIL
HORIZONTAL

PLOT
873
164
1263
311
deprivation cost
time
deprivation  cost
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"POD 1" 1.0 0 -2674135 true "" ";plotxy ticks sum [depcost] of people with [distance turtle 5 = 0 or target = turtle 5]"
"POD 2" 1.0 0 -11221820 true "" ";plotxy ticks sum [depcost] of people with [distance turtle 2 = 0 or target = turtle 2]"
"POD 3" 1.0 0 -1184463 true "" ";plotxy ticks sum [depcost] of people with [distance turtle 3 = 0 or target = turtle 3]"
"POD 4" 1.0 0 -8630108 true "" ";plotxy ticks sum [depcost] of people with [distance turtle 4 = 0 or target = turtle 4]"

INPUTBOX
179
10
332
70
init-random-seed
4.0
1
0
Number

SWITCH
0
297
168
330
show-truck-route?
show-truck-route?
1
1
-1000

SLIDER
1
64
173
97
number-of-DCs
number-of-DCs
1
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
0
136
172
169
truck-stops
truck-stops
1
10
1.0
1
1
NIL
HORIZONTAL

INPUTBOX
174
300
333
360
POD-SUPPLIES
750.0
1
0
Number

PLOT
873
10
1263
163
deprivation time
time
deprivation time
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Person a" 1.0 0 -16777216 true "" ";plotxy ticks [depticks ] of person 81"
"Person b" 1.0 0 -2064490 true "" ";plotxy ticks [depticks ] of person TRACK-PERSON-ID"

PLOT
873
313
1265
463
person b
time
cumulative deprivation cost
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"cumu_1" 1.0 0 -16777216 true "" ";plotxy ticks sum [totaldepcost] of people with [distance turtle 2 = 0 or target = turtle 2]"
"cumu_depco" 1.0 0 -2064490 true "" ";;plotxy ticks [totaldepcost] of person TRACK-PERSON-ID\n"

CHOOSER
176
180
330
225
people-next-stop
people-next-stop
"nearest" "random"
0

CHOOSER
177
78
330
123
DCs-allocation-policy
DCs-allocation-policy
"continous" "fixed-interval"
1

CHOOSER
177
129
331
174
PODs-allocation-policy
PODs-allocation-policy
"continous" "fixed-interval"
1

INPUTBOX
176
235
333
295
DCs-allocation-interval
14400.0
1
0
Number

SWITCH
0
336
167
369
load-input-location?
load-input-location?
0
1
-1000

SWITCH
1
370
166
403
load-dc-supplies?
load-dc-supplies?
1
1
-1000

SWITCH
0
409
164
442
load-delivery-trip?
load-delivery-trip?
1
1
-1000

INPUTBOX
0
173
171
233
total-supplies
3000.0
1
0
Number

INPUTBOX
0
236
168
296
server
1.0
1
0
Number

INPUTBOX
173
368
333
428
truck-capacity
750.0
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
  <experiment name="exp1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="13500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="810000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="13500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="810000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp3" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="27000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="1620000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="27000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="1620000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp5" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="27000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="1620000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp6" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="40500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp7" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="40500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp8" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="40500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp9" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="40500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp10" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="40500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp11" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="60750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp12" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="60750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp13" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="60750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp14" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="60750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp15" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="60750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="2430000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp16" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="9000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp17" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="9000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp18" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="9000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp19" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="19"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp20" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp21" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="21"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp22" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp23" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="23"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp24" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp25" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp26" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp27" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp28" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp29" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp30" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp31" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp32" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="300000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp33" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp34" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp35" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp36" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp37" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp38" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp39" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp40" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="number-of-DCs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="server">
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-supplies">
      <value value="225000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-PODs">
      <value value="25"/>
    </enumeratedValueSet>
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


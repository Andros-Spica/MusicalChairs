;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  The Musical Chairs model - A model of the interaction between farming and herding (REVISITED v2)
;;  Copyright (C) 2016 Andreas Angourakis (andros.spica@gmail.com)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;;;;;;;;;;;;;;;;
;;;;; BREEDS ;;;;
;;;;;;;;;;;;;;;;;

breed [ stakeholders stakeholder ]

;;;;;;;;;;;;;;;;;
;;; VARIABLES ;;;
;;;;;;;;;;;;;;;;;

globals
[
  totalPatches

  ;;; modified parameters
  initH initF
  intGrowthF intGrowthH maxExtGrowthF maxExtGrowthH
  hrmi herdingIntegration farmingIntegration

  ;;; counters and final measures
  countLandUseF countLandUseH
  competitions landUseChangeEvents
  farmingDemand farmingGrowth farmingDeterrence farmingBalance
  herdingDemand herdingGrowth herdingDeterrence herdingBalance
  meanFarmingIntensity meanHerdingIntensity
  meanFarmingIndependence meanHerdingIndependence
]

patches-own [ landUse myStakeholder contenders ]

stakeholders-own [ hasLand activity intensity independence ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup

  clear-all

  set totalPatches count patches

  ;;; setup parameters depending on the type of experiment
  if (typeOfExperiment = "random")
  [
    ; set random seed
    let aSeed new-seed
    random-seed aSeed
    set seed aSeed

    set intGrowthF 0.01 + random-float farming_intrinsic_growth_rate
    set maxExtGrowthF 0.001 + random-float max_farming_extrinsic_growth_rate
    set farmingIntegration random-float 1
    set intGrowthH 0.01 + random-float herding_intrinsic_growth_rate
    set maxExtGrowthH 0.001 + random-float max_herding_extrinsic_growth_rate
    set herdingIntegration random-float 1
    set initH random round ((init_herding / 100) * totalPatches)
    set initF random round ((init_farming / 100) * totalPatches)
    set hrmi ((1 + (random-float 10) ) / (1 + (random-float 10) )) ;; set a random value between 0.1 and 10 (around 1)
  ]
  if (typeOfExperiment = "defined by GUI")
  [
    ; set random seed
    random-seed seed

    set intGrowthF farming_intrinsic_growth_rate
    set maxExtGrowthF max_farming_extrinsic_growth_rate
    set farmingIntegration farming_integration
    set intGrowthH herding_intrinsic_growth_rate
    set maxExtGrowthH max_herding_extrinsic_growth_rate
    set herdingIntegration herding_integration
    set initH round ((init_herding / 100) * totalPatches)
    set initF round ((init_farming / 100) * totalPatches)
    set hrmi herding_relative_max_intensity
  ]
  if (typeOfExperiment = "defined by expNumber")
  [
    ; set random seed
    let aSeed new-seed
    random-seed aSeed
    set seed aSeed

    load-experiment
  ]

  ;;; set land use according to the parameter setting (position is arbitrary and has no consequence)
  ask patches [ set landUse "N" set myStakeholder nobody set contenders (turtle-set) ]
  ask n-of initF patches
  [
    set landUse "F"
    sprout-stakeholders 1
    [
      set hidden? true
      set hasLand true
      set activity "F"
      set intensity random-float 1
      set independence random-float 1
    ]
    set myStakeholder one-of stakeholders-here
  ]
  ask n-of initH patches with [landUse = "N"]
  [
    set landUse "H"
    sprout-stakeholders 1
    [
      set hidden? true
      set hasLand true
      set activity "H"
      set intensity random-float hrmi
      set independence random-float 1
    ]
    set myStakeholder one-of stakeholders-here
  ]

  ;;; initialize visualization
  update_visualization

  reset-ticks

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; CYCLE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  ;;; This procedure is the cycle of the model (what happens during one "tick").

  reset-counters

  growth

  landUse-expansion

  check_competitions

  update_visualization

  tick
  if ticks > endSimulation [stop]

end

to reset-counters

  ;;; This procedure reset all counters which are used either during the cycle or summarized at the "update-visualization" procedure.

  set farmingDemand 0
  set herdingDemand 0
  set farmingGrowth 0
  set farmingDeterrence 0
  set herdingGrowth 0
  set herdingDeterrence 0
  set competitions 0
  set landUseChangeEvents 0

end

to growth

  ;;; This procedure calculates the demand for each land use class, based on both the intrinsic and extrinsic growth rates of each of them.
  ;;; Note that growth rates are dependent on parameters, but also on the context, and may vary from one "tick" to another.

  ;;; FARMING
  ;;; Intrinsic Demand
  ask patches with [landUse = "F"]
  [
    if ( random-float 1 <= intGrowthF )
    [
      sprout-stakeholders 1
      [
        set hidden? true
        set hasLand false ;;; still landless
        set activity "F"
        set intensity [intensity] of myStakeholder
        set independence [independence] of myStakeholder
      ]
      set farmingDemand farmingDemand + 1
    ]
  ]
  ;;; Extrinsic Demand
  let extF (round (maxExtGrowthF * ( totalPatches - countLandUseF ) ) )
  repeat extF
  [
    ask patch 0 0
    [
      sprout-stakeholders 1
      [
        set hidden? true
        set hasLand false ;;; still landless
        set activity "F"
        set intensity random-float 1
        set independence random-float 1
      ]
    ]
    set farmingDemand farmingDemand + 1
  ]

  ;;; HERDING
  ;;; Intrinsic Growth
  ask patches with [landUse = "H"]
  [
    if ( random-float 1 <= intGrowthH )
    [
      sprout-stakeholders 1
      [
        set hidden? true
        set hasLand false ;;; still landless
        set activity "H"
        set intensity [intensity] of myStakeholder
        set independence [independence] of myStakeholder
      ]
      set herdingDemand herdingDemand + 1
    ]
  ]
  ;;; Extrinsic Demand
  let extH (round (maxExtGrowthH * ( totalPatches - countLandUseH ) ) )
  repeat extH
  [
    ask patch max-pxcor max-pycor
    [
      sprout-stakeholders 1
      [
        set hidden? true
        set hasLand false ;;; still landless
        set activity "H"
        set intensity random-float 1
        set independence random-float 1
      ]
    ]
    set herdingDemand herdingDemand + 1
  ]

end

to landUse-expansion

  ;;; This procedure calls for the expansion procedures of farming and herding, intentionally in this order.

  farming-expansion
  herding-expansion

end

to farming-expansion

  if (any? stakeholders with [ activity = "F" AND hasLand = false ])
  [
    ask stakeholders with [ activity = "F" AND hasLand = false ]
    [
      if (any? patches with [landUse != "F"]) ;;; Fit-to-maximum exclusion
      [
        let me self
        ask one-of patches
        [
          let aPatch self
          if (landUse != "F") ;;; Density-dependent exclusion
          [
            ifelse (landUse = "N")
            [
              ;;; the farming stakeholder will start using the unused land
              set landUse "F"
              set myStakeholder me
              ask me [ set hasLand true move-to aPatch ]

              set landUseChangeEvents landUseChangeEvents + 1
              set farmingGrowth farmingGrowth + 1
            ]
            [
              if ( [independence] of me > (count patches with [landUse = "H"] / totalPatches) ) ;;; Volition-opportunity exclusion
              [
                ;;; the farming stakeholder will start using the pastureland
                set landUse "F"
                ask myStakeholder [ set hasLand false ]
                set myStakeholder me
                ask me [ set hasLand true move-to aPatch ]

                set landUseChangeEvents landUseChangeEvents + 1
                set farmingGrowth farmingGrowth + 1
                set herdingDeterrence herdingDeterrence + 1
              ]
            ]
          ]
        ]
      ]
    ]
  ]
  ask stakeholders with [ activity = "F" AND hasLand = false ] [ die ]

end

to herding-expansion

  ;;; reset herding patches (herds go back not necessarily to the same patch), but keep track of the herding stakeholders that already used the territory
  let oldHerdingStakeholders [myStakeholder] of patches with [landUse = "H"]
  ask patches with [landUse = "H"]
  [
    ask myStakeholder [ set hasLand false ]
    set myStakeholder nobody
  ]

  if (any? stakeholders with [ activity = "H" AND hasLand = false ])
  [
    ask stakeholders with [ activity = "H" AND hasLand = false ]
    [
      if (any? patches with [myStakeholder = nobody]) ;;; Fit-to-maximum exclusion
      [
        let me self
        let aPatch one-of patches
        if (member? me oldHerdingStakeholders)
        [
          set aPatch one-of patches with [myStakeholder = nobody] ;;; herding stakeholders that already visited the territory do not suffer the Density-dependent exclusion
        ]
        ask aPatch
        [
          ask me [ move-to aPatch ]
          ifelse (myStakeholder = nobody) ;;; Density-dependent exclusion
          [
            ifelse (landUse = "N")
            [
              ;;; the herding stakeholder will start using the unused land
              set landUse "H"
              set myStakeholder me
              ask me [ set hasLand true ]

              set landUseChangeEvents landUseChangeEvents + 1
              set herdingGrowth herdingGrowth + 1
            ]
            [
              ;;; the herding stakeholder will start using the temporally unoccupied land
              set myStakeholder me
              ask me [ set hasLand true ]
            ]
          ]
          [
            if (landUse = "F")
            [
              ;;; the herding stakeholder will press to use a farming patch
              set contenders (turtle-set contenders me)
            ]
          ]
        ]
      ]
    ]
  ]

  ;;; rangelands not claimed will be considered free land (no land use)
  if (any? patches with [landUse = "H" and myStakeholder = nobody] ) [ ask patches with [landUse = "H" and myStakeholder = nobody] [ set landUse "N" ] ]

end

to check_competitions

  ask patches with [ landUse = "F" AND count contenders > 0 ]
  [
    repeat count contenders [ resolve_competition ]
  ]
  ask stakeholders with [ activity = "H" AND hasLand = false ] [ die ]

end

to resolve_competition

  ;;; set competition conditions
  let aPatch self
  ;;;;; select one farming stakeholder and its supporters, calculate the intensity of the farming land use involved in a land use unit
  let defender myStakeholder
  let farmingSupporters round (farmingIntegration * ((count stakeholders with [activity = "F"]) - 1))
  let farmingSupport 0
  if (farmingSupporters > 0) [ set farmingSupport sum [intensity] of n-of farmingSupporters stakeholders with [activity = "F" AND self != defender] ]
  let farmingIntensity ([intensity] of myStakeholder + farmingSupport )

  ;;;;; select one herding stakeholder and its supporters, calculate the intensity of the herding land use to be involved in the same land use unit
  ;;; get contender and exlude it from contenders
  let contender one-of contenders
  set contenders contenders with [self != contender]
  let herdingSupporters round (herdingIntegration * ((count stakeholders with [activity = "H"]) - 1))
  let herdingSupport 0
  if (herdingSupporters > 0) [ set herdingSupport sum [intensity] of n-of herdingSupporters stakeholders with [activity = "H" AND self != contender] ]
  let herdingIntensity ([intensity] of contender + herdingSupport )

  ;;;;; calculate the ratio of intensities, the index of opportunity and the incentives for relinquish, all taken from the perspective of herding land use
  let ratio_of_intensities  (herdingIntensity /(farmingIntensity + herdingIntensity))
  let index_of_opportunity ((count patches with [landUse = "F"]) / totalPatches)
  let incentives_to_relinquish (1 - (ratio_of_intensities * index_of_opportunity))

  ask contender
  [
    ;;; Does the herding stakeholder attempt to replace the farming stakeholder?
    ifelse ( independence < incentives_to_relinquish)

    ;;; No. The herding stakeholder is repressed.
    [ die ]

    ;;; Yes. A competitive situation is produced.
    [
      set competitions (competitions + 1)

      ;;; Does the competitive situation evolves into a land use change event?
      ifelse (random-float 1 < ratio_of_intensities)

      ;;; Yes. The farming stakeholder is repressed.
      [
        ask defender [ die ]
        set myStakeholder contender
        set hasLand true
        set landUse "H"
        set landUseChangeEvents landUseChangeEvents + 1
        set herdingGrowth herdingGrowth + 1
        set farmingDeterrence farmingDeterrence + 1
      ]

      ;;; No. The herding stakeholder is repressed.
      [ die ]
    ]
  ]

end

to update_visualization

  set farmingBalance (farmingGrowth - farmingDeterrence)
  set herdingBalance (herdingGrowth - herdingDeterrence)

  set countLandUseF count patches with [landUse = "F"]
  set countLandUseH count patches with [landUse = "H"]

  ifelse (countLandUseF > 0)
  [
    set meanFarmingIntensity (mean [intensity] of stakeholders with [activity = "F"])
    set meanFarmingIndependence (mean [independence] of stakeholders with [activity = "F"])
  ]
  [
    set meanFarmingIntensity ""
    set meanFarmingIndependence ""
  ]

  ifelse (countLandUseH > 0)
  [
    set meanHerdingIntensity (mean [intensity] of stakeholders with [activity = "H"]) / hrmi
    set meanHerdingIndependence (mean [independence] of stakeholders with [activity = "H"])
  ]
  [
    set meanHerdingIntensity ""
    set meanHerdingIndependence ""
  ]

  update-patches

end

to update-patches

  ask patches
  [
    set pcolor brown
    if (landUse = "F")
    [ set pcolor green ]
    if (landUse = "H")
    [ set pcolor yellow ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; Parametrization from file ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to load-experiment

let FilePath "SensAnalysis//exp//"
let filename (word FilePath "exp_" expNumber ".csv")
file-open filename
while [not file-at-end?]
[
  set intGrowthF file-read
  set maxExtGrowthF file-read
  set farmingIntegration file-read
  set intGrowthH file-read
  set maxExtGrowthH file-read
  set herdingIntegration file-read
  set initH file-read
  set initF file-read
  set hrmi file-read

  set endSimulation file-read ;- 1500 ;; use this to cut down the time of simulation (e.g. if the file reads 2000)
]
file-close

end
@#$#@#$#@
GRAPHICS-WINDOW
782
10
1327
148
-1
-1
5.35
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
99
0
19
0
0
1
ticks
30.0

BUTTON
18
174
81
207
NIL
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
93
175
156
208
NIL
go
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
166
176
229
209
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
1

SLIDER
-1
335
224
368
farming_intrinsic_growth_rate
farming_intrinsic_growth_rate
0
0.1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
3
495
228
528
herding_relative_max_intensity
herding_relative_max_intensity
0.1
10
1
0.1
1
NIL
HORIZONTAL

PLOT
270
10
745
186
land use
ticks
patches
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"herding" 1.0 0 -1184463 true "plot countLandUseH" "plot countLandUseH"
"farming" 1.0 0 -13840069 true "plot countLandUseF" "plot countLandUseF"

PLOT
969
186
1144
306
herding independence
NIL
frequency
0.0
200.0
0.0
200.0
false
false
"set-plot-x-range 0 1" "set-plot-y-range -0.01 countLandUseH"
PENS
"independence" 1.0 1 -16777216 true "histogram [independence] of stakeholders with [activity = \"H\"]\nset-histogram-num-bars 10" "histogram [independence] of stakeholders with [activity = \"H\"]"

PLOT
293
187
745
355
events
ticks
events
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"competitions" 1.0 0 -16777216 true "" "plot competitions"
"landUseChangeEvents" 1.0 0 -5825686 true "" "plot landUseChangeEvents"

SLIDER
-1
441
224
474
max_herding_extrinsic_growth_rate
max_herding_extrinsic_growth_rate
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
2
557
227
590
farming_integration
farming_integration
0
1
0
0.01
1
NIL
HORIZONTAL

SLIDER
2
590
227
623
herding_integration
herding_integration
0
1
0
0.01
1
NIL
HORIZONTAL

SLIDER
-1
368
224
401
max_farming_extrinsic_growth_rate
max_farming_extrinsic_growth_rate
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
-1
408
224
441
herding_intrinsic_growth_rate
herding_intrinsic_growth_rate
0
0.1
0.05
0.01
1
NIL
HORIZONTAL

PLOT
969
309
1143
429
farming independence
NIL
frequency
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 1" "set-plot-y-range -0.01 countLandUseF"
PENS
"independence" 1.0 1 -16777216 true "histogram [independence] of stakeholders with [activity = \"F\"]\nset-histogram-num-bars 10" "histogram [independence] of stakeholders with [activity = \"F\"]"

PLOT
752
187
912
307
herding intensity
NIL
frequency
0.0
10.0
0.0
10.0
false
false
"set-plot-x-range 0 hrmi\nset-histogram-num-bars 10" "set-plot-y-range -0.01 countLandUseH"
PENS
"default" 1.0 1 -2674135 true "histogram [intensity] of stakeholders with [activity = \"H\"]" "histogram [intensity] of stakeholders with [activity = \"H\"]"

PLOT
752
309
912
429
farming intensity
NIL
frequency
0.0
10.0
0.0
10.0
false
false
"set-plot-x-range 0 1\nset-histogram-num-bars 10" "set-plot-y-range -0.01 countLandUseF"
PENS
"default" 1.0 1 -955883 true "histogram [intensity] of stakeholders with [activity = \"F\"]" "histogram [intensity] of stakeholders with [activity = \"F\"]"

PLOT
304
356
745
495
balance
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"farming agents" 1.0 0 -13791810 true "" "plot farmingBalance"
"herding agents" 1.0 0 -10873583 true "" "plot herdingBalance"
"0" 1.0 0 -16777216 true "" "plot 0"

MONITOR
224
331
291
368
NIL
intGrowthF
4
1
9

MONITOR
224
368
299
405
NIL
maxExtGrowthF
4
1
9

MONITOR
224
405
293
442
NIL
intGrowthH
4
1
9

MONITOR
224
441
301
478
NIL
maxExtGrowthH
4
1
9

MONITOR
228
493
278
530
NIL
hrmi
4
1
9

MONITOR
227
552
310
589
NIL
farmingIntegration
4
1
9

MONITOR
227
589
310
626
NIL
herdingIntegration
4
1
9

MONITOR
688
62
745
99
patches
totalPatches
0
1
9

MONITOR
465
495
557
532
NIL
farmingGrowth
2
1
9

MONITOR
561
495
662
532
NIL
farmingDeterrence
2
1
9

MONITOR
465
534
557
571
NIL
herdingGrowth
2
1
9

MONITOR
562
534
662
571
NIL
herdingDeterrence
2
1
9

MONITOR
687
147
780
184
farming (% patches)
100 * countLandUseF / totalPatches
2
1
9

MONITOR
912
222
962
259
average
meanHerdingIntensity
2
1
9

MONITOR
914
350
964
387
average
meanFarmingIntensity
2
1
9

MONITOR
1144
224
1194
261
average
meanHerdingIndependence
2
1
9

MONITOR
1144
347
1194
384
average
meanFarmingIndependence
2
1
9

MONITOR
618
248
707
285
NIL
competitions
0
1
9

MONITOR
618
289
743
326
NIL
landUseChangeEvents
0
1
9

MONITOR
655
495
745
532
NIL
farmingBalance
2
1
9

MONITOR
655
534
745
571
NIL
herdingBalance
2
1
9

INPUTBOX
170
86
242
146
seed
-53324005
1
0
Number

TEXTBOX
101
152
153
170
Controls
14
0.0
1

TEXTBOX
51
10
209
28
Experiment configuration
14
0.0
1

CHOOSER
60
33
192
78
typeOfExperiment
typeOfExperiment
"defined by GUI" "random"
1

INPUTBOX
86
86
169
146
endSimulation
500
1
0
Number

INPUTBOX
14
86
85
146
expNumber
0
1
0
Number

TEXTBOX
77
217
179
235
Initial conditions
14
0.0
1

SLIDER
9
241
187
274
init_farming
init_farming
0
100
15
1
1
% patches
HORIZONTAL

SLIDER
9
277
187
310
init_herding
init_herding
0
100
15
1
1
% patches
HORIZONTAL

MONITOR
187
237
267
274
initF (% patches)
initF / totalPatches
2
1
9

MONITOR
187
276
267
313
initH (% patches)
initH / totalPatches
2
1
9

TEXTBOX
86
314
167
332
Growth rates
14
0.0
1

TEXTBOX
98
477
153
495
Intensity
14
0.0
1

MONITOR
387
495
462
532
NIL
farmingDemand
0
1
9

MONITOR
386
534
462
571
NIL
herdingDemand
0
1
9

TEXTBOX
86
538
155
556
Integration
14
0.0
1

MONITOR
687
110
780
147
herding (% patches)
100 * countLandUseH / totalPatches
2
1
9

@#$#@#$#@
## WHAT IS IT?

The Musical Chairs (MC) model intends to explore the conditions for the emergence and change of land use patterns in Central Asian oases and similar contexts. Land use pattern is conceptualized as the proportion between the area used for mobile livestock breeding (herding) and sedentary agriculture (farming), the main forms of livelihood from the Neolithic to the Industrial Revolution. We assume that these different forms of land use interact in recurrent competitive situations (presumably, but not necessarily, yearly-basis), given that the land useful for both activities is limited and there is a pressure to increase both classes of land use, due to demographic and/or economic growth. This is the first and most simple model of a series dedicated to this objective. See RELATED MODELS below.

## HOW IT WORKS

The MC model is a mechanism that assign stakeholders and their particular variant of land use (agents or "turtles") to the land use by them (patches). It represents a context where farming (sedentary land use) and herding (seasonal mobile) land use compete seasonally for a limited space. Although patches DO represent spatial units, spatial relationships (neighborhood, distance) are not relevant in this model.

The cycle begins with the calculation of the demand for land of both farming and herding (`growth` procedure). The demand may be generated by intrinsic (_density dependent_) or extrinsic (_density independent_) factors. Demand is here translated as the introduction of new stakeholders, which either inherit the traits of the "parent" stakeholder (if generated by intrinsic growth) or have random traits (if generated by extrinsic growth).

The satisfaction of all land use demand is done by the expansion of each land use class (`expansion` procedures). First, expansion is constrained by the density of the respective land use class. The more extended a land use class, the fewer opportunities to expand. Farming stakeholders attempting to settle over pastures can do it without causing a competitive situation (farming settling predates the return of herds). They will decide to settle by comparing their own dependence to herding stakeholders (trait `independence`) against the overall presence of herding in the territory, up to the moment. Moreover, herding stakeholders arrive in a random order and consider the access to pastureland to be open, which implies that older stakeholders have the additional risk of being put off by newer stakeholders. After the expansion procedure, some herding stakeholders may remain landless, some pressing against farming stakeholders (as `contenders`), others simply dispersing or exiting the territory.

The procedure `check-competitions` iterate over all patches resolving all competitions posed by the herding contenders. The `resolve-competition` procedure includes two steps: (1) the herding contender will be able to assess the probability of overcoming the influence of farming (`ratio_of_intensities`), the marginal value of the patch (`index_of_opportunity`), and compare them to its independence to farming; (2) if the contender insists producing a competitive situation, a stochastic test using the `ratio_of_intensities` will determine whether the contender occupies the patch or not.

## HOW TO USE IT

First, you should select the desired type of experiment (`typeOfExperiment`):

* "defined by GUI": all values introduced by the user in sliders, boxes, and choosers (except `expNumber`) will be applied.

* "random": randomly selects values for all the parameters (except `expNumber` and `endSimulation`).

* "defined by expNumber": the setup procedure will call for the `load-experiment` procedure, which set the parameters using the values of a "exp_<expNumber>.csv" file, if available. The seed for the random number generator is set randomly.

GUI elements:

* `endSimulation`: the number of cycles to simulate.

* `seed`: set the seed for the random number generator. The same integer number will always generate the same simulation, given the same parameter configuration.

* `init_farming`: the initial percentage of patches used for farming.

* `init_herding`: the initial percentage of patches used for herding.

* `farming_intrinsic_growth_rate`, `herding_intrinsic_growth_rate`: the intrinsic growth for farming/herding land use per patch (0.05 = 5%).

* `max_farming_extrinsic_growth_rate`, `max_herding_extrinsic_growth_rate`: the maximum value of the extrinsic growth for farming/herding land use (0.1 = 10%).

* `herding_relative_max_intensity`: the maximum intensity of herding stakeholders, relative to the maximum intensity of farming stakeholders, which always equals to __one__.

* `farming_integration`, `herding_integration`: the proportion of farming/herding stakeholders that will or can support their own land use class in a competitive situation.

## THINGS TO NOTICE

The MC model describes the implications of the alternation between a non-competitive period, where stakeholders and their activities grow their land use demand, and a competitive period, where both expanding forces press for their interests with asymmetric conditions (sedentary versus mobile activities). Simulations with balanced overall intensities (`herding_relative_max_intensity` around 1) and integration levels (`farming_integration` equal to `herding_integration`) show a clear trend favoring the expansion of farming.
The model demonstrates the role of competition in selecting for intensity and independence, but also how higher levels of integration smooth the selection for intensity.

## THINGS TO TRY

* Which parameters facilitate the formation of balanced land use patterns? Are these patterns stable?

## RELATED MODELS

TO DO

## CREDITS AND REFERENCES

Further information can be found in the ODD protocol and the following publication:

Angourakis et al. (2014) Land Use Patterns in Central Asia. Step 1: The Musical Chairs Model. Journal of Archaeological Method and Theory, Speacial Issue on Computer Simulation.
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="ext0intg0_init100vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg0_init100vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg0_init200vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg0_init200vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg1_init100vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg1_init100vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg1_init200vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext0intg1_init200vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg0_init100vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg0_init100vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="farming_max_intensity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg0_init200vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg0_init200vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg1_init100vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg1_init100vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg1_init200vs100" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ext25intg1_init200vs200" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="randomized" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>totalPatches</metric>
    <metric>intGrowthF</metric>
    <metric>intGrowthH</metric>
    <metric>maxExtGrowthF</metric>
    <metric>maxExtGrowthH</metric>
    <metric>initH</metric>
    <metric>initF</metric>
    <metric>hrmi</metric>
    <metric>herdingIntegration</metric>
    <metric>farmingIntegration</metric>
    <metric>countLandUseF</metric>
    <metric>countLandUseH</metric>
    <metric>competitions</metric>
    <metric>landUseChangeEvents</metric>
    <metric>farmingDemand</metric>
    <metric>farmingGrowth</metric>
    <metric>farmingDeterrence</metric>
    <metric>farmingBalance</metric>
    <metric>herdingDemand</metric>
    <metric>herdingGrowth</metric>
    <metric>herdingDeterrence</metric>
    <metric>herdingBalance</metric>
    <metric>meanFarmingIntensity</metric>
    <metric>meanHerdingIntensity</metric>
    <metric>meanFarmingIndependence</metric>
    <metric>meanHerdingIndependence</metric>
    <enumeratedValueSet variable="herding_relative_max_intensity">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_farming_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_intrinsic_growth_rate">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_herding_extrinsic_growth_rate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herding_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farming_integration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_herding">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init_farming">
      <value value="100"/>
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

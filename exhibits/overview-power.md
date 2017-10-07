Along with breathable air, potable water, and propellant, perhaps the most critical spacecraft-supplied consumable resource was electricity. Suffice it to say that Apollo 13 could not have made it home without power, and the nature of the accident meant that power was in very short supply indeed.

The combined Command Module/Service Module (CSM) stack was powered by three fuel cells located in the Service Module, as well as five batteries located in the Command Module. The Lunar Module, on the other hand, had aboard only two batteries to support its mission. Typically, it relied on power supplied over an umbilical from the CSM whenever attached, so as not to needlessly drain its batteries.

Fuel Cells
----------

At a very high level, fuel cells look very similar to batteries. They involve a metallic cathode and anode, and an electrolyte medium immersing and connecting the two just like a battery does. However, where a battery becomes depleted over time due to the static nature of these three components, a fuel cell avoids this problem by deriving its electric potential from constantly flowing and thus replenished chemicals on the porous cathode and anode ends.

{{figure:eps-thumbnail}}

The Apollo Fuel Cell design is known as an Alkaline or a Bacon Fuel Cell, and consumes pure hydrogen and oxygen gas fed from cryogenic tanks in the Service Module, with a static potassium hydroxide (KOH) electrolyte mediating the two, and produces electricity, heat, and potable water. On the anode side, the hydrogen gas reacts with spare hydroxide ions to produce water and electrons (2H&#8322; + 4OH&#8315; &rarr; 4H&#8322;O + 4e&#8315;), whilst on the cathode side oxygen gas and electrons returning from their circuit through the various powered components on the spacecraft would interact to form hydroxide ions (O&#8322; + 2H&#8322;O + 4e&#8315; &rarr; 4OH&#8315;). The electrolyte would carry the hydroxide ions across from the cathode to the anode to complete the sustained reaction loop.

While excess hydrogen could to some extent be separated from the water byproduct (which was potable and consumed by the crew) and recycled through the system, the oxygen gas was consumed as-needed, and any excess was simply vented out of the spacecraft. Indeed, both halves of the fuel cell gas subsystems would be periodically purged of stale gas to ensure their ongoing purity.

{{figure:o2-thumbnail}}

Reactant purity is quite important. Because the static electrolyte design employed by NASA did not naturally reject carbon dioxide, pure oxygen had to be used. This is because potassium hydroxide could break down or transform into potassium carbonate with the infiltration of carbon dioxide, a state known as elecrolyte poisoning which could lead not just to reduced performance but to [dangerous explosive situations](https://blogs.nasa.gov/waynehalesblog/2009/01/07/post_1231342021582/) due to imbalances in the carefully measured chemical reactions. The pH Hi indicator on the MDC, which operated based on the acidity of the water byproduct of the reaction, was important as it provided a leading indicator of this potential situation.

Each of the three Apollo Fuel Cells actually contained 31 individual 1 volt cells, each of which carried out this reaction process, and which were wired together to provide the 28 volt baseline power the various components required at up to 1420 watts. The fuel cells were, due to the efficiency of cryogenic gas storage, expected to supply the vast majority of power for any given Apollo mission. The surviving operation of any one cell was expected to ensure a safe return home, though nominally all three ran, distributed across the two DC buses.

Command Module batteries
------------------------

The Command Module was equipped with three primary rechargeable batteries, lettered A through C and primarily aimed at entry and postlanding operations, and two pyrotechnic batteries whose job was simply to provide the juice to fire various pyrotechnic charges throughout the duration of the flight. All five batteries were silver oxide-zinc in chemistry.

Of the three primary batteries, typically only A and B were kept on the line, while C was kept in reserve. Each was rated for 40 amp-hours, most of which each could deliver at up to 35 amps. The connections between the batteries and the rest of the electrical system were managed by a combination of the Main Bus Tie Bat A/C and B/C selector switches, which paired battery C with either of the other two, and individual circuit breakers for each battery.

A battery charger onboard could be connected to any of the three to charge them. It took in both DC and AC power&mdash;the three-phase AC was used to boost the DC supply up to 40 volts, and phase A was used to run some of the control circuitry&mdash;and contained filters and sensors to ensure appropriate power delivery for the battery profile.

The two pyro batteries were typically kept entirely off the line until needed, to isolate them from the rest of the power system. They were never to be charged during flight. In case of pyro battery failure, careful manipulation of the circuit breakers could bring any of the three primary batteries in as a replacement.

CSM Main DC buses
-----------------

The Command/Service Module combined spacecraft had two primary DC buses upon which power was routed. Not every component was connected to both buses, and in some cases redundant equipment was distributed between the two: of the three AC inverters, for example, one could only be connected to Main DC Bus A, the second only to Main B, whilst the third could be connected to either A or B.

Each bus had various diodes and current-sensing protections that would kick in to mitigate failure scenarios. An overload, for instance, would automatically disconnect the fuel cells from the system and warn the crew. Each bus was capable of handling all system load, so undervolts were not expected to occur. Of course, with a serious malfunction (as with Apollo 13) power generation could fall behind consumption and voltage could drop below 26.25V, the point at which an Undervolt warning light would appear.

Most of the components had individual protection via circuit breakers exposed on the Command Module panels. The circuit breakers were for far more than protection, however: they were used heavily to regulate which components were given power and when. Many of Apollo's checklists pertained to circuit breakers and the particular order they ought to be engaged and disengaged to ensure safe operation of the vehicle. It was also advantageous from a power consumption standpoint to keep components offline whenever they were not being used.

CSM AC power system
-------------------

{{figure:ac-phases}}

Some components are easier to engineer given AC power than DC. Universal motors, for instance, are very easy to construct and reliable under operation when fed three-phase AC power (your home likely receives two-phase AC power, with the two phases oscillating at a 180&deg; offset from each other; three-phase is the same concept but with three phases oscillating at 120&deg; offsets instead).

AC power generation was done by the three redundant AC inverters; their connection to the DC bus to draw source power is discussed above. Each inverter was an eight-stage solid-state unit comprised of many components related to generating oscillation, managing and filtering harmonic noise, rectifying the signal, and other standard inverter tasks.

Any of the three AC inverters could then be output onto either or both of the two AC buses, numbered 1 and 2. Many of the components that fed off the AC buses had three individual breakers, one for each phase. Others depended only on a particular phase. A fourth AC ground wire was circulated alongside the power phases, just as your AC appliances at home have a ground prong to go with the two powered phases.

Lunar Module batteries
----------------------

The Lunar Module was equipped with only batteries for operation. The two LM batteries were the same silver oxide-zinc batteries as found in the Command Module, but were each a much larger 296 amp-hour capacity instead. As a result, they weighed a fairly significant 57kg (125lb) each.

They could be charged off of the Command/Service Module power system via an umbilical that fed through the interior of the docking tunnel between the two modules. Typically, the Lunar Module wasn't powered up at all until the Apollo spacecraft was already in stable lunar orbit, at which point the fuel cell could easily sustain both craft for the short duration before undocking and lunar landing. The umbilical was not meant to send power in reverse to the Command/Service Module, a limitation that would end up being overcome over the course of Apollo 13.

The LM also featured an AC bus and two AC inverters.


There are no highway milepost signs in space, just vast swaths of nothing. This makes the problem of determining where exactly the spacecraft is&mdash;and indeed, even how fast it is traveling&mdash;a difficult task. In practice, the process of determining spacecraft position and velocity was accomplished through the combination of onboard inertial measurement instruments and ground-based tracking systems. The spacecraft's attitude, on the other hand, was determined and managed entirely using onboard instruments.

Inertial Guidance
-----------------

[Inertial Navigation Systems](https://en.wikipedia.org/wiki/Inertial_navigation_system) were relatively fresh inventions as of Apollo. They were created out of necessity along with the first ballistic missile and spaceflight missions, and by the time of Apollo were relatively well-understood. On Apollo, the Inertial Measurement Unit (IMU) was the instrument that performed most of the inertial measurement required.

{{figure:imu}}

As explained in the [Spaceflight 101 Primer](#primer-spaceflight), the IMU involved a gyroscope: a powered spinning weight that created rotational inertia such that when mounted as a primary unit (called the Stable Member) within three freely rotating gimbal rings it would hold its orientation as the spacecraft it was mounted upon turned about. This is a lot like holding a compass in your hand and turning your body about in different directions while watching the needle stay still relative to the Earth, except around three axes rather than one, and with rotational inertia rather than magnetic force holding the central unit in place.

In addition to the rotary encoders (called resolvers) that read the gimbal ring orientations and deduced spacecraft attitude, there were also linear accelerometers mounted within the inner primary unit that measured spacecraft acceleration in three dimensions. However, velocity is the important measure required for navigation, and acceleration is a step removed from velocity. To obtain velocity, one must integrate acceleration over time: accumulate (add or subtract) samples of momentary acceleration as frequently as possible into a single overall value. Because this task is essentially impossible without a computer, inertial navigation was an early motivator for the miniaturization of computers. Even in P00 idle mode, the Apollo Guidance Computer would never forsake the task of integrating its state vectors over time.

Where velocity is acceleration integrated over time, position is velocity integrated over time. Each of the two levels of indirection between the physically measurable acceleration value and the desired position value required for accurate navigation added imprecision, and meant that onboard instruments could not alone adequately navigate the spacecraft. Imagine trying to precisely measure the distance traveled on a highway by nothing more than sampling your speedometer over time, and then imagine that you have not a speedometer but instead an accelerometer.

Something more precise is needed for accurate navigation, and ideally something that can directly answer the "where is the spacecraft?" question at any moment in time without relying on previous answers being correct.

Manned Spaceflight Network
--------------------------

{{figure:msfn-sites}}

An offshoot of the NASA Deep Space Network, the Manned Spaceflight Network (MSFN) was a collection of 14 ground, 4 sea, and 8 air-based stations around the world that tracked the Apollo spacecraft for the duration of its mission. Using large 26 meter (85ft) antenna dishes, these stations performed the critical operations of providing communications to and from the spacecraft as well as information about its position and velocity. After all, if one is to aim a communications dish at the appropriate spot in the sky, one must understand where the target object is.

The Deep Space Network had been in operation since 1958, and its primary task at inception was to track and maintain bidirectional communications with unmanned spacecraft. When the manned spaceflight program began, concerns around ceding system time away from extant programs led to the establishment of the MSFN and the procurement of additional on-site equipment to increase the operational capacity of the existing stations. Using techniques such as radar ranging and doppler analysis, the communications signal itself could be used to help triangulate the position of the spacecraft. Because this was an instantaneous measurement from the stability of the ground, these measurements were highly reliable.

One MSFN station in particular would become crucial during Apollo 13: [Honeysuckle Creek](https://honeysucklecreek.net/). Located in Canberra, Australia, the station was on duty during the [communications issues](#59:36:27) experienced around four hours following the Apollo 13 accident caused by signal interference between the Lunar Module and the S-IVB booster stage on its way to impacting the Moon. The Honeysuckle Creek website linked above is an excellent resource for learning more about the ground tracking network in general.

Determining Attitude
--------------------

The MSFN ground tracking stations help augment the accuracy and reliability of the onboard IMU by providing accurate point-in-time measurements of spacecraft position and velocity. But with the IMU alone, measurement of spacecraft attitude (orientation) depended exclusively on the accuracy over time of a gimbaled gyroscope (or the backup BMAGs which could measure only momentary rotational accerelation). If the IMU hit gimbal lock, or if the gyro itself simply drifted over time due to friction and vibration, as it was known to do, the attitude numbers lost their validity. Something else was required, which again would ideally provide a definitive answer without relying on prior measurements.

{{figure:aot-starchart}}

The solution was the same as that employed by mariners upon the ancient sea: to look to the stars. A built-in onboard sextant called the Alignment Optical Telescope (AOT) could be used to sight known stars. Once star positions were confirmed and locked in, the computer could calculate its attitude relative to the universe and a fresh set of numbers could be obtained.

The AOT had some neat tricks: the swivel mount had sensors in it, so once the astronaut had it aligned with the desired star, there was no need to read and key in numbers: the computer could read them automatically once instructed to.

The process of spacecraft alignment was referred to by the AGC program numbers used to execute the sighting and alignment: P51 and P52. A P51 determined from scratch the spacecraft attitude relative to the IMU, using the telescope to sight two different known stars. Upon completion of alignment process, the computer would output a number indicating the relative error of the resulting numbers: inaccurate sightings of the stars relative to each other could be detected in the math that followed. When the error number read all zeroes, this was referred to as ["all balls"](https://www.youtube.com/watch?v=5jCyE0me41Y). A P52, on the other hand, would automatically point the AOT to allow the crew to visually reconfirm the previous sighting through the telescope. If things still looked good, the program would proceed to physically reorient the central Stable Member of the IMU to a desired angle, typically to best-avoid gimbal lock.

Of course, this entire process depends on being able to reliably identify particular stars. Apollo 13's accident meant that thousands of tiny shiny debris particles were adrift in space in a cloud around the spacecraft, obscuring or confusing the star field behind them. This, along with glare from the still-attached CSM, led to issues and frustrations in attempting to align the platform for [the critical burn](#60:23:00) roughly five hours following the accident to set the ship up for a safe slingshot back home around the Moon.


Overview
--------

Getting to the Moon and home again involved a small number of broad, basic tasks:

* **Propulsion**: Getting to orbit in space, and changing that orbit to meet and subsequently orbit the Moon.
* **Navigation**: Understanding where the spacecraft was and which way it was pointed.
* **Systems and Life Support**: Keeping the spacecraft and astronauts alive, powered, and temperature-regulated.

While Apollo was, in aggregate, an immensely complex system comprised of countless components, miles of wiring and circuitry, and cutting-edge-for-the-time technology, we can vastly simplify our effort to understand the spacecraft by approaching it at a high level from these four fundamental problem areas. Each is covered in detail in the Overview section.

There are a few other elemental concepts to understand before diving in:

Redundancy 101
--------------

Sending humans into space is a big deal, and it's dangerous. While it may be mechanically simple to think about propulsion, navigation, and life support, the reality is that things fail. Nearly every NASA mission at this point had a major quirk or two to deal with.

The most robust way to deal with failure is to increase the safety factor by introducing redundant systems. Each Space Shuttle Main Engine, for example, had two computers with two processors each, and a system that would redelegate control if errant calculations were detected. But in the Apollo days, redundancy didn't always mean identical backups. Often, to save weight, money, or complexity, the redundant systems were actually entirely independent designs. Sometimes this could actually be an advantage, as different designs will have different strengths and weaknesses, and thus different failure points.

The Commmand Module, for example, had one primary navigational sensor: the Inertial Measurement Unit. The IMU was a big powered gyroscope that tracked orientation, much like your smartphone today can detect how it's being tilted and rotated around. The IMU gyroscope was mounted on three freely rotating gimbal axes; it's a lot like turning about while holding a compass, except instead of magnetic force it is the rotational inertia of the spinning gyro that holds the "needle" still, and instead of one axis around which to rotate there are three. This allowed it to read the spacecraft's absolute orientation relative to its static reference angle, much like you can always read your bearing relative to magnetic North on a compass. This allowed great precision and confidence, but it also created a problem state known as gimbal lock, as the three gimbals together couldn't quite follow the spacecraft across certain extreme angles.

The backups to the IMU, then, were known as Body Mounted Attitude Gyros, or BMAGs. There were two of them, and rather than turning about freely on gimbals, they were locked down [rate gyros](https://en.wikipedia.org/wiki/Rate_gyro). This meant they could only measure the _change_ of orientation rather than measure the absolute orientation. This is a bit like telling how far you've driven down a highway by sampling your speedometer over time and doing some math: it _ought_ to work, but tiny imprecisions in measurement can throw you off. A really long tape measure will give you an absolute answer with far more confidence, and so the IMU was the preferred instrument. But, the BMAGs were lighter, and because no gimbals were involved they were not susceptible to gimbal lock.

Another example is the Abort Guidance System (AGS) on board the Lunar Module. It served as the backup to the Apollo Guidance Computer (AGC) and some of its associated sensor systems, in case it failed during a landing. But in that case, the landing is off and the focus moves to getting back to orbit and rendezvousing with the still-orbiting Command/Service Module for the trip home; a much simpler task. Thus, the AGS had far fewer features than the AGC&mdash;and simplicity is often a recipe for greater robustness. You'll hear discussion of using the less power-hungry AGS in lieu of the AGC for the trip around the Moon in the final stages of the audio recording.

Lastly, sometimes redundancy simply wasn't practical. The Command/Service Module had two main DC electrical buses (A and B) that circulated electricity around the spacecraft. With hundreds or thousands of total sensors and components to wire, you can imagine that sending two entire loops of wiring to every single piece of electronics was not only infeasible, it would mean greater chance of mistakes or accidents, and a far heavier spacecraft. In some cases, this meant that some instruments or components were only available on one bus or the other. In other cases, a hybrid approach was taken: of the three inverters that converted DC to AC power, for example, the first could only pull electricity off the A bus, the second only the B bus, and the third inverter could draw from either A or B.

Orbital Mechanics 101
---------------------

[Much has been written](http://www.braeunig.us/space/orbmech.htm) about this popularly misunderstood and rather counterintuitive topic. We can avoid most of the details here, and instead focus on developing a basic-enough grasp to understand what is happening in these six hours.

The first thing to understand is that given any instantaneous velocity (speed and direction) and position of an object above Earth, we can definitively (with some handwaving) calculate its entire orbit. This follows from computing Newton's Law of Gravitation, `F=GmM/R`, over time. This rule isn't terribly intuitive or informative on its own, but it helps us think about what happens when we change the parameters involved. For example, it is not possible to speed up or slow down without profoundly affecting the shape of one's orbit. This is commonly misunderstood and incorrectly depicted in popular films.

The second thing to understand is _just how fast_ orbital speed is. In Earth orbit roughly 100nm (155mi/185km) above the surface, the Apollo spacecraft would typically be travelling at over 28,000km/h (~17,500mph). Most of a rocket's launch efforts are not invested in pushing the spacecraft up, but rather in hurling it sideways.

The reason this is important to understand is because one must realize how little impact maneuvering or even full engine burns have on a spacecraft's _immediate_ location or trajectory. A typical Apollo burn might modify its speed by somewhere between 20km/h and 150km/h. The more intense burns that flung the spacecraft to and from the Moon required changes in speed of upwards of 10,000km/h&mdash;much more, but that 50% increase in speed accounts for the difference between a low 185km Earth orbit and an orbit that reaches the Moon, some 385,000km (~240,000mi) away.

{{figure:orbits-fail}}

Instead, what a burn has far more impact on is the overall shape of the orbit. Let's try this out (**figure 1**). On the left is a typical Apollo orbit just after launch: the numbers described just above. The orbit and planet are to scale, while the spacecraft is blown up so you can see which way it's burning. Notice how close the orbit is to the surface of the planet, despite the spacecraft being well into space. We want to go to the moon, so let's wait until we're as close as possible, point at it, and burn for a little bit. We will increase our speed by 5,400 km/h to 32,400 km/h.

That didn't work at all. In fact, despite going faster we are now destined to crash back into Earth. This is because we forgot about our second observation, that our burns are relatively small percentages of the spacecraft's base speed. We're not going to be able to overwhelm the momentary velocity taking us parallel to the Moon by adding a small percentage of it towards the Moon.

{{figure:orbits-prograde}}

Let's try working _with_ the speed we already have, then. We'll burn exactly the same amount, just in our direction of travel (**figure 2**).

That was more interesting. By burning in the same direction as our travel, we modified the opposite side of our orbit by moving it outwards significantly. Remember again: we can change the shape of our orbit by changing our speed, but most changes we can make don't really have much effect on our immediate local path. So all that change goes elsewhere in the orbit: in this case, to the opposite side.

It doesn't matter much today, but this is known as a **prograde** burn. Of course, if we wanted to go to the Moon, we'd want to do exactly the same thing but on the other side of Earth.

{{figure:orbits-retrograde}}

We can invert this effect by turning around so that instead our engines point in the direction of our travel, and burning. This is called a **retrograde** burn (**figure 3**).

{{figure:orbits-subtle}}

The final example (**figure 4**) demonstrates just how profoundly small changes in velocity can affect the orbit. From an orbit that just reaches the Moon, we'll decelerate by a mere 20m/s&mdash;not even highway car speed. It may not look like much on this extreme scale, but that small change is the difference between passing comfortably over the surface of the Earth by a margin of ~1,200,000km (~740,000mi) and smashing into the Earth while trying to pass ~270,000km (~168,000mi) below its surface.

When you listen to the astronauts worry about small details like the particular set of thrusters they are using to point the spacecraft in different directions, it is this effect that they are keenly aware of&mdash;particularly with a close approach to the Moon coming up.

There are other types of burns that do different things&mdash;we'll cover just one more. Prograde and retrograde burns modify the orbit, but only within the 2D plane in 3D space that the spacecraft is already travelling within. If that plane itself needs to change, this can be done by burning orthogonally to it. But recall again our second observation, that changing our immediate path is really difficult. Changing our plane necessarily involves changing our _entire_ path, including our immediate path. So this is really expensive to do, fuel-wise.

These burn examples illustrate the third thing to understand, which is that much like orbits, burns can be described by two basic parameters: the point in orbit of the burn and the change in velocity (commonly referred to as &Delta;V). Because rocket engines do not instantaneously modify a spacecraft's speed by tens or hundreds of km/h and because it is easier to keep an eye on a clock than a position in the universe, this is more practically delivered to the astronauts and executed upon with three primary datapoints: wall-clock time of burn, attitude of the spacecraft during the burn, and how long to burn for. (Because spacecraft engines, especially the adjustable-throttle Lunar Descent engine, also do not instantaneously throttle up, there are additional parameters for that and other details.) These figures would be read up and written down on a pre-printed PAD form.

Our last note will be that nothing is ever so clean as presented here. In reality, any object orbiting anywhere in the Solar System is affected by a multitude of gravitational forces, the Earth is not actually spherical nor is its weight distributed evenly, and no burn is ever purely prograde or retrograde or plane change. Many, many factors go into actual orbital and burn calculation. For Apollo, these factors were all calculated on massive computers on the ground over the course of the mission.

Rocketry 101
------------

There is one very important thing to understand about rocketry itself: the fuel is most of the weight you carry into orbit. If you want to go a bit further, you have to add some fuel. But then you also have to carry that fuel to the new, further point you wish to burn it, so you have to add even more fuel just to carry that added fuel&mdash;and so on. This game hits diminishing returns pretty quickly, and it's why the Saturn V is as incredibly gigantic as it is.

But the flip-side of this is that the spacecraft gets vastly lighter as it burns that fuel, while the engines remain just as powerful. This means that by the time the spacecraft is on its way to the Moon, for example, and has burned most of its fuel, that little bit of fuel left can cause, percentage-wise, an immense amount of change in spacecraft velocity.

This nonlinearity is why rockets and spacecraft are typically not accounted in terms of liters or gallons of fuel remaining, but rather in &Delta;V remaining: how much more change in velocity do we have in reserve?

It is also a big factor in the design of the Apollo architecture, as we shall cover briefly.


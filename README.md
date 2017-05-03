Apollo 13 real-time
===================

This project consists of two efforts:

* One is a **full digital transcription** of the Apollo 13 Flight Director's Loop, the audio of which is generously provided to the public by NASA through the efforts of [John Stoll](https://archive.org/details/Apollo13Audio). The full transcript may be found under the `script/` directory. Timing is based on [corrected playback audio](https://www.youtube.com/watch?v=KWfnY9cRXO4) done by [ulysses777x](https://www.youtube.com/user/ulysses777x) on YouTube.
* The second is a web player for this audio which plays the audio side-by-side with the transcript, with as much additional interactive information as we can provide to help contextualize the loop chatter for curious folk who are unfamiliar with Apollo systems and terminology.

These six hours are a priceless artifact, shedding light on the strength and style of leadership of NASA's flight directors as well as the resourcefulness, knowledge, and grace under pressure of the astronauts and flight controllers alike—but also on the moment-to-moment realities of spaceflight. By listening to this audio, you begin to understand what life was like for the crew in space and the controllers on the ground, as they execute burns and solve problems, as well as the mechanics of spaceflight in the Apollo era.

Transcription
-------------

While there is an [official transcription](https://www.jsc.nasa.gov/history/mission_trans/apollo13.htm) of the air-ground loop provided by NASA, one does not exist for the Flight Director's Loop. In addition, the official transcript doesn't always line up with the audio timing, and does not provide timestamps for the _end_ of each transmission. As a result, we also maintain our own transcription of the air-ground loop.

The two loops are transcribed independently based on the timing-corrected version of John Stoll's upload (see above). Each is in its own text file within the `/script` directory. The transcripts follow a common format:

    [55 05 00 - 55 05 12] FLIGHT
    This is a 12-second line from the Flight Director that began at 55 hours and 5 minutes flat.

    [55 05 14] EECOM
    When the end timestamp is omitted, the line is a short utterance of around a second or less.
    > This is a commentary note on the line as a whole.

    [55 05 21 -] FLIGHT
    When there is a dash but no end time -

    [55 05 25] GNC
    {Negative,} FLIGHT.
    1> A numbered commentary note relates to the {bracketed text} in the line. Multiple brackets and numbers may be used.

    [- 55 05 30] FLIGHT
    - a single line was interrupted briefly by another line in a way that was hard to separate.

This raw transcript format integrates all the interactive transcript display in the web player, such that anybody can use the GitHub text editor to recommend changes or additions.

Compilation scripts in the `/script` directory compile this raw format into two separate artifacts: one is a JSON-formatted file for the benefit of the web player and other programmatic purposes, and the second is a raw transcript with all annotations removed and formatted for maximum plain-text readability, for those who wish to just have the transcribed text to read.

Web player
----------

To be developed and settled down: content to follow here.

License
=======

As the raw audio is provided by NASA as a public service, and the transcription and development work herein is done under the spirit of public service, the entire contents of this repository are provided under the most generous license available: either Public Domain, or [CC Zero](https://creativecommons.org/publicdomain/zero/1.0/), depending on the licensee's legal preferences.

This includes all contributed work: contributors, please be aware that you agree to this by contributing to this repository. All contributors will be recognized in the web player.

Attribution is, of course, appreciated—but not required.


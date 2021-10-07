Apollo 13 real-time
===================

This project consists of three efforts:

* One is a **full digital transcription** of the Apollo 13 Flight Director's Loop, the audio of which is generously provided to the public by NASA through the efforts of [John Stoll](https://archive.org/details/Apollo13Audio). The full transcript may be found under the `script/` directory. Timing is based on the IRIG-B timed multitrack audio now available as of 2020.
* The second is a web player for this audio which plays the audio side-by-side with the transcript, with as much additional interactive information as we can provide to help contextualize the loop chatter for curious folk who are unfamiliar with Apollo systems and terminology. The code for this is found in the `webapp/` directory.
* The third are a series of brief articles, high-quality diagrams, and other resources aimed at easing laypeople into spaceflight, and providing deeper technical information for those who desire it. These are located under the `exhibits/` directory, and are written in markdown and HTML to ease contribution.

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
    {Negative}, {FLIGHT}.
    1> A numbered commentary note relates to the {bracketed text} in the line.
    2> Multiple brackets and numbers may be used.

    [- 55 05 30] FLIGHT
    - a single line was interrupted briefly by another line in a way that is hard to separate.

This raw transcript format integrates all the interactive transcript display in the web player, such that anybody can use the GitHub text editor to recommend changes or additions.

Compilation scripts in the `/script` directory compile this raw format into two separate artifacts: one is a JSON-formatted file for the benefit of the web player and other programmatic purposes, and the second is a raw transcript with all annotations removed and formatted for maximum plain-text readability, for those who wish to just have the transcribed text to read.

Web player
----------

The web player is written in [Janus](/clint-tseng/janus), a functional reactive programming framework. It was written in a bit of a rush, so it isn't the cleanest code, but if active development continues a few small refactors should bring it into line. Of note are `app.ls`, which kickstarts the entire application and `model.ls` which defines all the viewmodel behaviour of the application.

To build and run the web player, first compile the scripts as describe in the previous section, then simply run `make` in the `webapp/` directory. You'll have to then serve the `lib/` directory at the root level of a web server; you'll want to use something full-fledged like nginx if you wish for audio seeking to work correctly (this rules out eg Python's `SimpleHTTPServer`).

Kiosk Modes
===========

It is easy to create a kiosk installation of this application, which adjusts the layout for optimal full-screen display on a television, or presents only the exhibit and reference material. All you have to do is direct a web browser at particular URLs:

* [`/?kiosk`](http://apollo13realtime.org/?kiosk) will show only the audio controls, transcripts, and glossary, and will begin playing the audio automatically. When the audio reaches the end, the page will refresh and the audio will begin playing again.
* [`/?kiosk#56:56:56`](http://apollo13realtime.org/?kiosk#56:56:56) is exactly the same as `/?kiosk`, but will cue the audio to begin playing from a particular timestamp. In fact, you can direct the browser to navigate to a timestamp hash at any time and the audio will begin playing there.
* [`/?exhibit`](http://apollo13realtime.org/?exhibit) will show only the exhibit section, starting with the table of contents. This is useful if you wish to dedicate an entire or noninteractive display to the audio player, but still want to provide access to the additional material.
* [`/?exhibit#primer-apollo`](http://apollo13realtime.org/?exhibit#primer-apollo) is exactly the same as `/?exhibit`, but will automatically open a particular article. Controls will still be present to dismiss that article and display another. To find the identifier associated with an article, use the filenames you find [here](https://github.com/clint-tseng/apollo13rt/tree/master/exhibits), without extensions.

If you have feedback, suggestions, or problems, please don't hesitate to let us know: either by filing a ticket on the issues page here, or reaching out to us directly. And if you do feature this experience somewhere, we'd absolutely love to see pictures and hear about it!

License
=======

As the raw audio is provided by NASA as a public service, and the transcription and development work herein is done under the spirit of public service, the entire contents of this repository are provided under the most generous license available: either Public Domain, or [CC Zero](https://creativecommons.org/publicdomain/zero/1.0/), depending on the licensee's legal preferences.

This includes all contributed work: contributors, please be aware that you agree to this by contributing to this repository. All contributors will be recognized in the web player.

Attribution is, of course, appreciated—but not required.


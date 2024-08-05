---
title: Dead Simple Media Server
category: projects
description: Media Server using Apache directory listing and html5
published: 2016-06-13
---
So you've got a lot of movies and music and photos sitting on your hard drive. Uselessly. They are thrown around in great big piles, copied over from your last backup, which contains another backup, which contains a chain of copies leading back to the dawn of the last ice age. They have names like **[XvID]SUPER TROOPERS- RIP by Xtralaxxxx69_part1.AVI**. You don't remember where they are, what they are named, what quality, or even that you have them in your posession. You never view, watch, or listen to them. You have no idea how to play them on your phone, and less so regarding your TV. You would like a solution to these problems, a solution that lets you browse all your media at a moments notice from anywhere in your home.

There are a few prominent solutions, like [Plex](https://plex.tv/) and [Subsonic](http://www.subsonic.org/pages/index.jsp) and [Universal Media Server](http://www.universalmediaserver.com/). But they are overcomplicated, they run on big runtimes (e.g. Java), they take up lots of resources, they are all *heavy*. Not ideal for a home server, unless you don't mind running a powerful PC 24/7. A better solution for a home server is an embedded ARM board (e.g. [Raspberry Pi](https://www.raspberrypi.org/)) that is quiet and takes up minimal power. Even better, run this server on a board that is also your router. But embedded boards can't handle *heavy*; you have to find something simple and *light*.

The solution I found is simply [Apache Web Server](https://httpd.apache.org/), which can run on almost anything and serve up your pictures, music, and video thanks to a bit of [HTML5 magic](http://www.w3schools.com/html/html5_video.asp). A [Chromecast](https://www.google.com/intl/en_us/chromecast/?utm_source=chromecast.com) can solve the difficulty of viewing on your TV. But creating this media server will also take some diligence organizing and converting your files. I'll break down how you can handle your files, set up Apache, and start watching. This is not a step-by-step tutorial however. I am only providing useful bits and pieces. I assume that you have the knowledge to put the pieces together as well as add your own.

## Video

I recommend putting all of your movies in one folder but each TV series into its own.

Movies and TV series can be renamed with [Filebot](http://www.filebot.net/), though honestly I wish I had a better piece of software to recommend. It does a good job but hangs up and crashes constantly. Avoid using it on overly large sets of files at one time.

Apache can serve up seekable video to your browser as long as it is in an [HTML5 compatible format](http://www.w3schools.com/html/html5_video.asp). The common demoninator amongst the most prominent browsers is MP4, specifically the MPEG-4 container with H.264 video and AAC audio. You can use a file:// URL to use your web browser as a file browser and see what videos can play. You might find some play but without audio, or some play with just audio, or not at all.

The simple command to convert your video to a good format is:

`ffmpeg -i input -c:v libx264 -preset slow -crf 18 -c:a aac -movflags +faststart output.mp4`

Most of the details behind that command can be found [here](https://trac.ffmpeg.org/wiki/Encode/H.264). It will take any video and convert it to the format we want with essentially no quality degradation, along with a slight optimization for web video. The problem is, it takes a long time. And it can be brutally inefficent. Using the above command on a video that already has H.264 video, but has an oddball audio stream that needs to be converted, will *still* decode and encode the video, rather than just copying the video stream. To make things a little more efficient, I created this script:

```
#!/bin/bash
VID_TARGET="-c:v libx264 -preset slow -crf 18"
AUD_TARGET="-c:a aac"
EXT_TARGET="-movflags +faststart"

VID_CODEC=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "${1}")
AUD_CODEC=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "${1}")
echo "${1}:${VID_CODEC}:${AUD_CODEC}"

if [ "${VID_CODEC}" == "h264" ]; then
	VID_TARGET="-c:v copy"
fi

if [ "${AUD_CODEC}" == "aac" ]; then
	AUD_TARGET="-c:a copy"
fi

ffmpeg -i "${1}" ${VID_TARGET} ${AUD_TARGET} ${EXT_TARGET} "${1%.*}.mp4"
```

Save that as 'mp4ize', and bulk convert your media with:

`find . -not -name '*.mp4' -type f -exec mp4ize {} \;`

Run it overnight on large file sets.

## Audio

I recommend putting all of your music into one big folder. This way, when you serve up the folder in an Apache directory listing, you can script up a media player that can use all of your music as a playlist, complete with 'shuffle' and other media controls. Batch convert any oddball formats to mp3 with:

`find . -not -name '*.mp3' -type f -exec bash -c 'ffmpeg -i "$0" -c:a libmp3lame -qscale:a 0 "${0%.*}.mp3"' {} \;`

Music can be identified, tagged, and renamed with the excellent [MusicBrainz Picard](https://picard.musicbrainz.org/). I recommend using an 'Artist - Album - Title' naming scheme, which can be achieved in Picard with:

`$if2(%albumartist%,%artist%) - $if(%album%,%album% - %title%,%title%)`

## Photo

I have not personally tried this yet, but [this](http://www.linuxjournal.com/content/tech-tip-automaticaly-organize-your-photos-date) seems like a great way to organize photos. You might also want to check out [fdupes](https://github.com/adrianlopezroche/fdupes) to get rid of duplicates, since photos tend to get hit worst by the 'hastily made backups' problem.

## Apache

For a basic setup, you'll want to point Apache to your media folder (in my case mounted on an external USB drive), and allow the `Indexes` option. Now you can easily browse your files with a browser (on mobile or PC), and thanks to HTML5, you can play audio and video right in your browser. But by default, you can only play one file at a time, and it doesn't look pretty. That's where [Apaxy](http://adamwhitcroft.com/apaxy/) comes in. Apaxy makes directory listings beautiful and provides an excellent base for tweaking styles and adding functionality.

Apaxy is really just a set of files and .htaccess rules. It is only a theme that takes advantage of Apache's many built-in customization options. One of these options is the 'HeaderName' directive which points to an HTML file to be included first in every generated page. In that page you can put anything you want, including your own [custom media controls](http://www.w3schools.com/tags/ref_av_dom.asp) and fancy javascript. I used [this](http://www.actionshrimp.com/2009/03/using-lightbox-with-apache-directory-listings-as-an-image-gallery/) as a guide to use lightbox to display images nicely. I also heavily reworked the code to handle clicks to audio and video, automatically playing them in a media tag near the top of the page, and providing media controls for audio folders. I'll reproduce a signifigant portion of the code here for you to adapt for your own purposes:

**Additions to .htaccess:**

```
	AddIcon (html5audio,/theme/icons/html5audio.png) .mp3 .wav .ogg .oga
	AddIcon (html5video,/theme/icons/html5video.png) .mp4 .ogv .webm
```

**header.html:**

```
<div class="header">
	<h1 id="header">Media Server</h1>
</div>

<audio style="display:none;" id="audio_play" preload="none" controls onended="audio_end()">
	<source id="audio_src" src="">
</audio>
<div style="display:none;" id="audio_bar" class="audiobar">
	<button id="prev" onclick="audio_prev()"></button>
	<button id="next" onclick="audio_next()"></button>
	<input type='checkbox' name='shuffle' id='shuffle'/><label for='shuffle'></label>
	<input type='checkbox' name='repeat1' id='repeat1'/><label for='repeat1'></label>
	<input type='checkbox' name='repeat' id='repeat'/><label for='repeat'></label>
</div>

<video style='display: none;' id="video_play" preload="none" controls>
	<source id="video_src" src="">
</video>

<script src="/theme/lightbox/js/prototype.js" type="text/javascript"></script>
<script src="/theme/lightbox/js/scriptaculous.js?load=effects,builder" type="text/javascript"></script>
<script src="/theme/lightbox/js/lightbox.js" type="text/javascript"></script>
<script src="/theme/page.js" type="text/javascript"></script>

<div class="wrapper">
<!-- we open the `wrapper` element here, but close it in the `footer.html` file -->
```

**Additions to style.css:**

```
tr[class$="html5audio"]:hover td, tr[class$="html5video"]:hover td {
	background-color: rgba(0,255,0,0.10);
}

audio::-webkit-media-controls-enclosure {
	max-width: 100%; /*or inherit*/
}

video, audio {
	margin-right:auto;
	margin-top: 20px;
	width: 1280px;
	max-width: 100%;
}

.audiobar {
	margin-top: 20px;
	width: 1280px;
	max-width: 100%;
	height: 30px;
	background: rgba(20, 20, 20, 0.8);
	border-radius: 5px;
	-webkit-user-select: none;
}

.audiobar input[type=checkbox] {
	display:none;
}

.audiobar input[type=checkbox] + label {
	display: inline-flex;
	width: 30px;
	height: 30px;
	-webkit-filter: brightness(1.6);
}

.audiobar input[type=checkbox]:checked + label {
	-webkit-filter: brightness(2.6);
}

.audiobar button:focus {
	outline:0;
}

.audiobar button {
	display: inline-flex;
	width: 30px;
	height: 30px;
	border: 0;
	-webkit-filter: brightness(2.6);
	position:relative;
}

.audiobar button:active {
	-webkit-filter: brightness(1.6);
}

#prev {
	margin-left: 10px;
	background: url(/theme/player_button_previous.png) 0px 5px/20px 20px no-repeat;
}

#next {
	background: url(/theme/player_button_next.png) 0px 5px/20px 20px no-repeat;
}

#shuffle + label {
	background: url(/theme/player_button_shuffle.png) 0px 5px/20px 20px no-repeat;
}

#repeat1 + label {
	background: url(/theme/player_button_repeat1.png) 0px 5px/20px 20px no-repeat;
}

#repeat + label {
	background: url(/theme/player_button_repeat.png) 0px 5px/20px 20px no-repeat;
}
```

**page.js**:

```
document.observe("click", function(event) {
	var element = Event.element(event);

	if (element.tagName == 'A') {
		// Clicked the table row link, not the image
		var colicon = element.up().up().down('td.indexcolicon');
		if(colicon) {
			var typeSrc = colicon.down().down().readAttribute('alt');

			switch(typeSrc) {
				case '[IMG]':
					event.stop();
					myLightbox.start(element);
					break;
				case '[html5audio]':
					event.stop();
					handleMediaLink(element,'audio');
					$('audio_play').show();
					$('audio_bar').show();
					break;
				case '[html5video]':
					event.stop();
					handleMediaLink(element,'video');
					window.scrollTo(0, 0);
					break;
				default:
			}
		}
	}
});

var lastLinkElementClicked;
function handleMediaLink(linkElement,typeStr) {
	var mediaElement = $(typeStr + '_play');

	// Remove hidden styling when media available
	mediaElement.show();

	if(lastLinkElementClicked) {
		lastLinkElementClicked.up().up().setStyle('background: white;');
	}
	linkElement.up().up().setStyle('background-color: rgba(0,255,0,0.25)');
	lastLinkElementClicked = linkElement;

	var href = linkElement.readAttribute('href');
	$(typeStr + '_src').setAttribute('src',href);
	var parsed = decodeURIComponent(href).replace(/\.[^/.]+$/, "");
	$('header').update(parsed);
	window.document.title = parsed;

	mediaElement.load();
	mediaElement.play();
}

function audio_end() {
	if($('repeat1').checked) {
		$('repeat1').checked = false;
		$('audio_play').play();
		return;
	}

	if($('repeat').checked) {
		$('audio_play').play();
		return;
	}

	audio_next();
}

// A real modulus, rather than the javascript builtin 'remainder' functionality that doesn't work well for negative numbers
function mod(n, m) {
	return ((n % m) + m) % m;
}

var audio_rows;
function audio_next() {
	if(!audio_rows) {
		audio_rows = $$('tr[class$="html5audio"]');
	}
	$('repeat').checked = false;
	$('repeat1').checked = false;

	var audio_row;
	if($('shuffle').checked) {
		audio_row = audio_rows[Math.floor(Math.random()*audio_rows.length)];
	} else {
		var currentIndex = audio_rows.indexOf(lastLinkElementClicked.up().up());
		audio_row = audio_rows[mod((currentIndex + 1), audio_rows.length)];
	}

	var audio_link = audio_row.down('td.indexcolname').down('a');
	handleMediaLink(audio_link,'audio');
}

function audio_prev() {
	if(!audio_rows) {
		audio_rows = $$('tr[class$="html5audio"]');
	}
	$('repeat').checked = false;
	$('repeat1').checked = false;

	var currentIndex = audio_rows.indexOf(lastLinkElementClicked.up().up());
	var audio_row = audio_rows[mod((currentIndex - 1), audio_rows.length)];

	var audio_link = audio_row.down('td.indexcolname').down('a');
	handleMediaLink(audio_link,'audio');
}
```

**Changes to lightbox.js:**

```
// loop through anchors, find other images in set, and add them to imageArray
for (var i=0; i<anchors.length; i++){
	var anchor = anchors[i];
	var colicon = anchor.up().up().down('td.indexcolicon')
	if(colicon) {
		var typeSrc = colicon.down().down().readAttribute('alt');
		if (typeSrc == '[IMG]'){
			imageArray.push(new Array(anchor.getAttribute('href'), anchor.getAttribute('title')));
		}
	}
}
```

To make changes easily, as well as upload files to your server, I recommend setting up [NFS](http://www.tldp.org/HOWTO/NFS-HOWTO/server.html).

### 2GB Limit#

A mysterious problem you may run into is that some files are missing. Specifically, files over 2GB do not show up in the listing and are not able to be served by Apache. Unless your Apache is really old, this is a problem that *only* affects cross-compiled Apache binaries, and stems from an issue with the build. The configure script for the [Apache Portable Runtime](https://apr.apache.org/) forces LFS (Large File Support) to be disabled when cross-compiling. You will have to rebuild Apache from source with the following hacky patch on APR:

```
diff --git a/configure b/configure
index 449c884..5bf1a4c 100755
--- a/configure
+++ b/configure
@@ -18706,7 +18706,7 @@ else
    apr_save_CPPFLAGS=$CPPFLAGS
    CPPFLAGS="$CPPFLAGS -D_LARGEFILE64_SOURCE"
    if test "$cross_compiling" = yes; then :
-  apr_cv_use_lfs64=no
+  apr_cv_use_lfs64=yes
 else
   cat confdefs.h - <<_ACEOF >conftest.$ac_ext
 /* end confdefs.h.  */
@@ -18748,7 +18748,7 @@ _ACEOF
 if ac_fn_c_try_run "$LINENO"; then :
   apr_cv_use_lfs64=yes
 else
-  apr_cv_use_lfs64=no
+  apr_cv_use_lfs64=yes
 fi
 rm -f core *.core core.conftest.* gmon.out bb.out conftest$ac_exeext \
   conftest.$ac_objext conftest.beam conftest.$ac_ext
```

Be aware that just because Apache has large file support, does not mean modules it interacts with do as well. I had to disable PHP in my case (not using it at the moment anyway) to stop Apache from crashing upon loading that module. The best way to debug Apache issues is to use `httpd -X` by the way.

### Large folders#

If you have any folders that take a long time to load, such as a Music folder with thousands of files in it, there is a hacky option to speed things up. Just `wget` the html *for* that folder *in* that folder. That will save an 'index.html' that Apache will serve up instead of trying to regenerate it on the fly. However, you will have to redo if you make changes to the folder, and you will lose sorting capability.

## Casting

So now you can view all of your media on your phone or PC, but you want to watch movies on your TV. Get yourself a [Chromecast](https://www.google.com/intl/en_us/chromecast/?utm_source=chromecast.com). They can be a bit fiddly at times, but they are easy and cheap. It is also best if you have an Android phone with Chrome on it. Any HTML5 video you view in that browser comes with a cast button, and it works just as well for video on your home server as it does videos on the internet. Oddly, the desktop Chrome does not currently have such support built in to the Google Cast extension, you can only cast the tab (which will essentially provide a kind of VNC, and limit the resolution). The [CastBuddy](https://chrome.google.com/webstore/detail/castbuddy/ghagedffjalchgcgdgfindabkpnmalel?hl=en) extension can be used instead, though for some reason it doesn't actually detect videos on the page, you have to give it the URL manually.

A word of caution however. If you happen to have a custom local domain name for your home server, by way of a local DNS server, be aware the Chromecast uses hard-coded DNS settings. It points to Google's public DNS 8.8.8.8, and doesn't know about your [jeffstotallyawesomemediaserver.com](http://jeffstotallyawesomemediaserver.com) name that only exists on your network. Casting using such an address will cause the Chromecast to start up, display the video title, then mysteriously blip back to the pretty photos. The easy workaround is to just browse and cast using your IP address. It should also be possible to create some iptables magic that forces the Chromecast DNS requests off to your server.

Another useful tool to know about is [castnow](https://github.com/xat/castnow), which is a simple command line application that allows for casting arbitrary videos from your PC. It works best with video that is already mp4, but it also has a `--tomp4` option to transcode on the fly.

I considered digging into the messy details of how `castnow` works in order to create casting buttons on the web page (likely through the use of CGI), but I think I'm calling it done for now. If anyone happens to succeed in doing that, please let me know.

## Conclusion

Enjoy the sweet taste of victory as you binge watch until your body becomes indiscernible from your couch.
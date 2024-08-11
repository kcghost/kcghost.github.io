---
title: Chromebook Thin Client
layout: article
category: blog
description: Building a great thin client out of a craptacular chromebook
published: 2024-08-11
---
I rescued an old chromebook from the trash by turning it into a thin client machine!

![Chromebook displaying this web page.](assets/img/chromebook.jpg "Look an infinity mirror effect would take all day, okay?" "Inception?")

We had a Samsung ["Snow"](https://chromebookdb.com/chromebook/samsung-arm-chromebook-series-3-xe303c12-a01us) chromebook that was collecting dust for years, now it hardly leaves my side. Out of the box it was a terrible machine.
It turns out forcing an underpowered laptop to only run a browser only works in an alternate reality where browsers and the websites they browse never got any more complex than geocities.
Ironically ChromeOS especially struggles with Google's own suite of web apps, even basic word processing is a chore.

But its an ARM-based machine that is light, small, quiet (no fan!), and power-efficient.
I have found it's a perfect form factor for getting real work done sitting on the couch, on the porch, or on the go.
It's also nice to get a change of scenery away from my basement office.

I managed to save it from the great landfill in the sky by:
{table-of-contents}

A good light Linux environment makes it a competent machine on its own if you mostly stick to the terminal. It struggles to run firefox though, you need to be careful about which websites to visit. I did find a browser called [netsurf](https://www.netsurf-browser.org/) that actually runs very well and is **not** just a another webkit or gecko derivative. But the catch is almost any website (including this one) will not render quite right. It isn't up to date with modern web standards like CSS3 yet.

But the real win comes from a VNC client to an older brother machine. I have a plenty powerful desktop machine that runs 24/7. With some hacks and trickery I regularly VNC right into the running X display, resize it to my smaller chromebook resolution, and pick up where I left off. Using a browser or anything else over VNC on my local network feels relatively seamless; I don't notice much lag at all.

## Putting a real Linux distro on it
Technically ChromeOS is already Linux, but you know what I mean.
At first I had Arch Linux on it, since at one point in time that was the only distro with [real support for this chromebook called out](https://archlinuxarm.org/platforms/armv7/samsung/samsung-chromebook). I managed to screw it up recently and had to wipe the thing and start from scratch. But now there are a few more options, including [this great script from 13pgeiser that builds a Debian system](https://github.com/13pgeiser/debian_chromebook_XE303C12). I prefer that anyway. I always come back to Debian or Ubuntu for the best package management money doesn't buy. The script boils down to marrying a hardware-specific kernel build to a userspace built with debootstrap/chroot. It's a great strategy for getting Debian on just about anything.

The flashing procedure for the ARM chromebooks is similar to an Android system in that you typically don't touch the existing bootloader. Instead you ask it pretty please stop enforcing your anti-consumer secure boot implementation.

* Enable Developer mode (only needed once)
	* Hold [[[[ESC]]+[[Refresh(F5)]]]] while powering on to enter recovery mode
		* Press [[[[Ctrl]]-[[D]]]] to enable "Developer" mode
			* Doing so will factory reset everything
		* If system is ever unbootable you can also prep a USB flash drive with the [ChromeOS installer](https://support.google.com/chromebook/answer/1080595?hl=en#zippy=%2Cuse-a-linux-computer) and boot it here.
* Boot ChromeOS
	* Enable USB Boot and disable signature checking
		* ```sample
[[[[Ctrl]] + [[Alt]] + [[T]]]]
crosh> [[shell]]
$ [[sudo su]]
$ [[crossystem dev_boot_usb=1 dev_boot_signed_only=0]]
```
* Prep a [Linux image on a USB drive](https://github.com/13pgeiser/debian_chromebook_XE303C12)
* Restart and boot into said USB drive
	* At bootup when Developer mode is enabled:
		* An annoying screen will pop up every boot now that waits for a key-combo
			* [[[[Ctrl]]-[[U]]]] to boot an external USB drive or SD card
			* [[[[Ctrl]]-[[D]]]] to boot the eMMC drive
			* [[[[Ctrl]]-[[I]]]] displays some helpful information, such as the status of allowing external boot or unsigned boot media
	* From there install it onto the main disk (ChromeOS will be overwritten)
		* The image built by `13pgeiser` provides a convenient installer script
* Press [[[[Ctrl]]-[[D]]]] every time you boot the laptop

**WARNING:**
These machines have a bug where they can "forget" that unsigned USB booting was enabled if they run down the battery too far. Oddly they don't tend to forget about dev mode.
If you happen to break the Linux boot *and* lose the USB booting, you may get locked out.
You can still recover using the recovery installer, but that normally wipes the whole system. I got bit by this bug myself and was forced to wipe my Arch system, before I learned there might have been a way to recover.
I haven't tried it, but there is an [old support page now only available on the web archive](https://web.archive.org/web/20231112055106/https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/workaround-for-battery-discharge-in-dev-mode/) that describes a procedure to modify the recovery installer so that it only re-enables `dev_boot_usb=1`.

It's possible to [permanently enable USB booting](https://github.com/hexdump0815/linux-mainline-and-mali-on-samsung-snow-chromebook/blob/legacy/misc.cbe/boot/cb-gbb.txt) among other things by removing a write-protect screw and setting so-called "GBB" flags.
The `flashrom` and `crossystem` tools that interact with the bootloader settings are ported to Debian, but they seem to be mostly dysfunctional. I had a hell of a time trying to build versions that actually work and got nothing to show for it.
Probably the most reliable way to use these low-level tools is from ChromeOS, possibly from a modified recovery installer.
I want to try this at some point to at least mess with the GBB flags.

## Ripping out systemd and replacing it
Nothing beats the sheer variety and quality of Debian packages, but that doesn't mean I'm entirely happy about the distro.
I just can't with `systemd`. Especially on a light system like this it can be inconsistent and slow for no good reason.

It's not for the faint of heart, but I use my [busyrc project](https://github.com/kcghost/busyrc) to replace systemd on my systems. It makes heavy use of a tool called [busybox](https://www.busybox.net/) that provides many standard Linux utilities in one executable, including an implementation of `init`. It sits close to the heart of many embedded Linux devs like myself.
I did need to push up a few improvements to networking stuff to the project in light of this install.
Once fixed all I needed to get online was to set up `/etc/wpa_supplicant.conf` with my wifi credentials.

I could (and probably should) build an image with [Devuan](https://www.devuan.org/) instead. But I think if I went that far I would make my own image builder scripts and sink a whole lot of time into it.

### Configuring init
The initial control point for busybox init is `/etc/inittab`.
inittab spawns both the logins for the ttys and calls a sysinit (busyrc in this case) for starting up all the system services.
For a system like this I just set all the ttys to autologin.
I also don't bother setting up a user besides `root`.
Worrying about `root` in a single-user system is [security theater anyway](https://xkcd.com/1200/).

```{filename=/etc/inittab}
tty1::respawn:agetty -a root tty1 linux
tty2::respawn:agetty -a root tty2 linux
tty3::respawn:agetty -a root tty3 linux
tty4::respawn:agetty -a root tty4 linux
tty5::respawn:agetty -a root tty5 linux
tty6::respawn:agetty -a root tty6 linux
tty7::respawn:agetty -a root tty7 linux

# Set MAXPLAYERS=0 in /etc/nethack/sysconf
tty8::respawn:/usr/games/nethack
```
```{filename=~/.profile}
# Start X on tty7 automatically
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty7" ]; then
    startx
fi
```
```sample
# fix ntp
$ [[adduser --system --no-create-home --group ntp]]
$ [[dpkg-reconfigure tzdata]]
# fix locales
$ [[update-locale --reset LANG=en_US.UTF-8]]
# fix minor wifi error
$ [[apt install wireless-regdb]]
``` 

### Handling the power button and lid switch
I added `@acpid` to my `/etc/busyrc.conf` to handle the power button and lid switch events.
`acpid` is an event listener that can run scripts on any [input event](https://www.kernel.org/doc/Documentation/input/event-codes.txt) coming out of `/dev/input/eventX` system-wide.

On this system there are three event char devices. `evtest` can be used to enumerate and dump them in real-time for testing.
```sample
$ [[evtest]]
No device specified, trying to scan all of /dev/input/event*
Available devices:
/dev/input/event0:  Cypress APA Trackpad (cyapa)
/dev/input/event1:  cros_ec
/dev/input/event2:  gpio-keys
Select the device event number [0-2]: [[2]]
Input driver version is 1.0.1
Input device ID: bus 0x19 vendor 0x1 product 0x1 version 0x100
Input device name: "gpio-keys"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 116 (KEY_POWER)
  Event type 5 (EV_SW)
    Event code 0 (SW_LID) state 0
```

The `gpio-keys` events are the most useful as those contain the power button and the lid switch. By handling these events you can shut down on power button press or turn off the backlight/suspend when the lid is closed. But you can also handle literally any keyboard press as well from `cros_ec`, maybe even trackpad events from `cyapa`.

**Note:** The busybox implementation of `acpid` is slightly different than the Debian package. I am using the busybox version here.

I need to configure `/etc/acpi.map` and `/etc/acpid.conf`, which are [closely related](https://wiki.alpinelinux.org/wiki/Busybox_acpid).
The busybox [acpid implementation](https://git.busybox.net/busybox/tree/util-linux/acpid.c) contains builtin defaults for both of these files, but they are incomplete and filled with misleading historical nonsense.

```{filename=/etc/acpi.map}
# Type(str) Type    Code(str)       Code Value "Description"
"EV_KEY"    0x01    "KEY_POWER"     116  1     "power_button_pressed"
"EV_SW"     0x05    "SW_LID"        0    0     "lid_opened"
"EV_SW"     0x05    "SW_LID"        0    1     "lid_closed"
```
```{filename=/etc/acpid.conf}
# Key                  Action
power_button_pressed   power    # Executes script: /etc/acpi/power 
lid_opened             lid/open
lid_closed             lid/close
```

Busybox doesn't actually care about the strings given for Type and Code ("EV_KEY", "KEY_POWER"), just their integer counterparts. So those are really just comments. The "description" does not reference event handler scripts directly. Instead the key given by `acpid.conf` is substring searched against the description and if it matches it executes the corresponding action script.

I'm never doing anything too important directly on the chromebook, so I prioritized aggressive power savings wherever possible.
```{filename=/etc/acpi/power}
#!/bin/sh

# Instant shutdown
shutdown -h now
```
```{filename=/etc/acpi/lid/close}
#!/bin/bash

# Kill the backlight
cur_brightness=$(</sys/class/backlight/backlight/brightness)
echo "${cur_brightness}" >/run/last_brightness
echo "0" >/sys/class/backlight/backlight/brightness

# Set CPU governor to powersave
echo "powersave" >/sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "closed" >/run/lid_status
```
```{filename=/etc/acpi/lid/open}
#!/bin/bash

# Set brightness back to last known value
last_brightness=$(</run/last_brightness)
echo "${last_brightness}" >/sys/class/backlight/backlight/brightness

# Set CPU governor back to ondemand
echo "ondemand" >/sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "open" >/run/lid_status
```

The whole top row of the keyboard has special symbols for special functions, but  are actually just function keys [[F1]] through [[F10]].
Experimentally I have tried binding brightness up and down scripts to the [[F6]] and [[F7]] keys, which have the appropriate symbols for that purpose. But `acpid` doesn't have a way to "swallow" those key presses, so they *also* keep doing whatever [[F6]] and [[F7]] do everywhere else. It would also be difficult to do any fancy key combinations without handling each key involved and keeping track of their state somewhere.

I think ideally I would remap the top row entirely to scripts and remap a key combination like [[Right Alt]]+[[F6]] to *actually* result in [[F6]] (or the other way around). Something akin to an [[Fn]] key this keyboard doesn't have. But I don't know of a convenient way of doing that system-wide that would work nicely both in virtual consoles and in Xorg. Also complex remapping in Xorg is a [dangerous mess](https://codeberg.org/ieure/xkbsucks) best left alone.

## Setting up a light desktop
`startx` needs something to start.
```{filename=~/.xinitrc}
[ -f ~/.xprofile ] && . ~/.xprofile
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.Xmodmap ] && xmodmap ~/.Xmodmap

# Need this here rather than in .profile for X11 Forwarding to work
refresh-desktop &

# Enable mousekeys so xmodmap bindings can use them
# Don't let mousekeys setting "expire"
xkbset m
xkbset exp "=mousekeys"

#xset s off
#xset -dpms
#xset s noblank

# Shutdown after 20 minutes of inactivity
xautolock -notify 30 -time 20 -locker "shutdown -h now" &

statusbar &
term &
exec dwm
```

`.Xresources` has my preferred terminal settings, fonts, and [colors](https://github.com/kcghost/cmtg).
I wrote a [separate post](2024-05-01-mousekeys.html) about `.Xmodmap` and the mousekeys. In place of a [[CapsLock]] key on this keyboard is a special key with a magnifying glass (Search?). I bound [[[[Search]]+[[a]]]] to left-click, [[[[Search]]+[[s]]]] to middle-click, and [[[[Search]]+[[d]]]] to right-click. It's amazing. It makes clicking and dragging a thousand times easier. This laptop has a *terrible* touchpad and these bindings are the only thing that makes it bearable.

```sample
# [[xset q | grep "Screen Saver" -A2]]
Screen Saver:
  prefer blanking:  yes    allow exposures:  yes
  timeout:  600    cycle:  600
```
By default X blanks the screen after 10 minutes of inactivity, which is fine for me.
I added `xautolock` not to lock the screen, but instead to just shut down after 20 minutes. Again for aggresive power savings. I do **not** want to run the battery down if I can help it.

`13pgeiser`'s image helpfully provides an xfce install script, but even xfce is a little heavy for this laptop.
Also with a resolution of 1366x768 screen real estate is at a premium, so a tiling window manager that does away with window decorations works best.
[suckless dwm](https://dwm.suckless.org/) fits the bill.

I use the standard [xresources patch](https://dwm.suckless.org/patches/xresources/) so I can [customize the colors to my liking](https://github.com/kcghost/cmtg). I also use `dwm` on my desktop and that has some special patches, but more on that later.

## SSH/VNCing to a Big Brother
The real magic is here.
```{filename=~/bin/refresh-desktop}
#!/bin/bash
# As soon as online (re-)establish a Control ssh session with desktop machine
# Useful for all the local forwarding to be available reliably, and for quick ssh terminals
# Assumes ssh config with ControlMaster/ControlPath

timeout_ms=250
wait_host() {
    # Try 
    export TIMEFORMAT=%R
    # Try 100 times in 25 seconds
    for i in $(seq 100); do
        # wait up to timeout ms, quit on first response
        # might fail early due to no network or failed lookup
        # time how long it takes, then sleep the remainder so each iteration takes around timeout ms
        # http://mywiki.wooledge.org/BashFAQ/032
        t=$( { time fping -q -c 1 -t${timeout_ms} "$1" >/dev/null 2>/dev/null; } 2>&1 )
        [ $? == 0 ] && break || sleep $(echo "scale=3;(0.${timeout_ms}-${t})*(0.${timeout_ms}>${t})" | bc)
    done
}

wait_host desktop.local

ssh -O exit "${ssh_target}"
ssh -N -f "${ssh_target}"
if ssh -O check "${ssh_target}"; then
    rterm &
    vncviewer :10 -Fullscreen
fi
```

```{filename=~/.ssh/config}
Host *
    ControlMaster auto
    ControlPath ~/.ssh/ssh_control_%h_%p_%r

Host desktop*
	User casey
	Hostname desktop.local
	ForwardX11 yes
	ForwardX11Trusted yes
	LocalForward 5900 localhost:5900
	# ...
	LocalForward 5999 localhost:5999
```

```{filename=~/bin/rterm}
#!/bin/bash
tabbed -r 4 -c xterm -bw 0 -into '' -e ssh -t desktop '/bin/bash' >/dev/null 2>&1 &
```

As soon as the network is up and able to find the big brother desktop machine:

* Establish a [re-usable SSH connection](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing)
* Port-forward the whole range of VNC ports
* Start a dedicated SSH terminal with [tabbed](https://tools.suckless.org/tabbed/) and `xterm`
* Automatically VNC into the desktop

### Employing Desktop Shenanigans
The catch is VNC'ing into a machine with a 1080p desktop from one that is...whatever 1366x768 is...is a pain. The default behavior from TigerVNC is not to downsample but to "bump scroll" when the cursor is near an edge. I find it to be pretty infuriating experience.
So instead I use some terrible hacks on the Desktop side.

```{filename=~/.xinitrc}
...
x11vnc -repeat -shared -localhost -forever -bg -N -display $DISPLAY
# special server for chromebook clipped size from origin
x11vnc -repeat -shared -localhost -forever -bg -rfbport 5910 -clip 1366x768+0+0 -display $DISPLAY
x11vnc -repeat -shared -localhost -forever -bg -rfbport 5911 -clip 1366x768+1920+0 -display $DISPLAY

# Fix shift-tab for vnc clients
# https://askubuntu.com/questions/839842/vnc-pressing-shift-tab-tab-only
xmodmap -e 'keycode 23 = Tab'

exec dwm
```

[x11vnc](https://linux.die.net/man/1/x11vnc) is an insanely powerful VNC server that just exposes an existing X session and has a thousand useful options in its man page. In addition to a "normal" VNC server (that would bump scroll on my chromebook) I host a couple special VNC servers (one for each monitor) that are clipped to the resolution of the chromebook. No more bump scroll!

Of course that simply clips off a big part of the desktop environment making it inaccessible. So my last trick is this awful patch to `dwm`:
```{filename=0001-bind-keys-to-a-hacky-downsize-and-resize-functions-f.patch}
From bedd8742d1731b6189341a99edb014a26c275067 Mon Sep 17 00:00:00 2001
From: Casey Fitzpatrick <kcghost@gmail.com>
Date: Fri, 1 Mar 2024 08:26:25 -0500
Subject: [PATCH] bind keys to a hacky downsize and resize functions for
 chromebook vnc

---
 config.h | 34 ++++++++++++++++++++++++++++++++++
 1 file changed, 34 insertions(+)

diff --git a/config.h b/config.h
index ec2114c..2f82f23 100644
--- a/config.h
+++ b/config.h
@@ -92,6 +92,9 @@ ResourcePref resources[] = {
 	{ "mfact",              FLOAT,   &mfact },
 };
 
+static void downsize(const Arg *arg);
+static void redosize(const Arg *arg);
+
 static const Key keys[] = {
 	/* modifier                     key        function        argument */
 	{ MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
@@ -131,6 +134,8 @@ static const Key keys[] = {
 	TAGKEYS(                        XK_8,                      7)
 	TAGKEYS(                        XK_9,                      8)
 	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} },
+	{ MODKEY|ShiftMask,             XK_d,      downsize,       {0} },
+	{ MODKEY|ShiftMask,             XK_r,      redosize,         {0} },
 };
 
 /* button definitions */
@@ -150,3 +155,32 @@ static const Button buttons[] = {
 	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
 };
 
+void resize_monitor(Monitor* m, int width, int height) {
+	Client *c;
+	// Leave sw and sh as the real values to come back to
+	if(width && height) {
+		m->mw = m->ww = width;
+		m->mh = m->wh = height;
+	} else {
+		updategeom();
+		width = m->mw;
+	}
+
+	for (c = m->clients; c; c = c->next)
+		if (c->isfullscreen)
+			resizeclient(c, m->mx, m->my, m->mw, m->mh);
+	updatebarpos(m);
+	XMoveResizeWindow(dpy, m->barwin, m->wx, m->by, m->ww, bh);
+
+	focus(NULL);
+	arrange(selmon);
+}
+
+// Hack to resize screen as if it were smaller for chromebook vnc
+void downsize(const Arg *arg) {
+	resize_monitor(selmon, 1366, 768);
+}
+
+void redosize(const Arg *arg) {
+	resize_monitor(selmon, 0, 0);
+}
-- 
2.25.1
```

I just VNC into my Desktop, then use [[[[Alt]]+[[Shift]]+[[D]]]] to "downsize" the window manager to 1366x768. If I walk back to my real desktop I resize it back again with [[[[Alt]]+[[Shift]]+[[R]]]].

It's truly awful but I love it. There is probably a better, more portable solution to this problem. I'm pretty sure there is some strange stuff you can do with [xrandr and virtual monitors](https://chipsenkbeil.com/notes/linux-virtual-monitors-with-xrandr/). Or maybe at least handle the VNC remote resize request somehow. But there is something undeniably satisfying in solving a problem by *hacking your window manager*.

### Controlling my Gaming PC
The very same big brother desktop is in a [multiseat configuration](https://wiki.archlinux.org/title/Xorg_multiseat) with two monitors at my "Desktop" in my dowstairs office and a TV for my "Couch" upstairs. Multiseat is a whole separate insanity I'll need to write a post on. But essentially it's acting like two separate PCs with two separate desktops running simultaneously.

One thing you **really** need for a couch gaming PC (or a home theater PC) is a convenient mouse and keyboard by your side. Even if you have it set up to start Steam Big Picture Mode automatically and you can pair a controller to browse and start games...you need a mouse and keyboard at least for when things go wrong. Which is all of the time. This is PC gaming we are talking about. On Linux no less.

Keyboards like the [Logitech K400](https://www.logitech.com/en-us/products/keyboards/k400-plus-touchpad-keyboard.920-007119.html) are a great fit for this. But if a tiny laptop is by your side, you can instead use its *own* trackpad and mouse to control the PC.

```{filename=~/bin/couch_control}
#!/bin/bash
# Treat the TV as a new monitor to the left of primary display
# Couch X server is on `:1`, for most people it would be `:0`
ssh -Y couch@desktop x2x -west -to :1.0
```

[x2x](https://linux.die.net/man/1/x2x) is a very old tool that has the effect of adding a remote monitor monitor to the Chromebook. It's as if I plugged the TV into HDMI and set the TV to the left of Primary. I can start up `couch_control` and move my cursor left onto the TV screen. I can type normally, fix up whatever, then bring the cursor back and [[[[Ctrl]]+[[C]]]].

## Hacking in USB-C PD
This Chromebook needs 12V power in from a barrel jack. It's inconvenient to lug around its bespoke power adapter, and times have (finally) changed. Ish.

I can power the chromebook with a standard(ish) USB-C PD brick and a USB-C cable with the help of a [USB PD Decoy Module](https://www.aliexpress.us/item/3256804650310482.html?spm=a2g0o.order_list.order_list_main.73.248d1802IvBHY8&gatewayAdapt=glo2usa). Requesting the correct voltage in the PD standard is not something that can be done with discrete components, so you do need something with an IC smart enough to talk to the PD brick for you.

Thankfully the decoy modules are cheap and it's a simple matter of ripping out the barrel jack, cutting some extra room in the plastic, soldering, and hot glueing everything in.

![USB-C port on back of Chromebook is flush but the hole it fits in is slightly too large and roughly cut. A small LED indicator to the left of the port is intact.](assets/img/pd_jack.jpg "You never see those marks on a sober man’s chromebook; never see a drunk’s without them" "Maybe not my best work, but that indicator light still works!")

There are several voltages in the PD standard but [not all PD adapters support 12V anymore](https://www.reddit.com/r/UsbCHardware/comments/i53olb/why_doesnt_pd_have_a_12v_profile/). But many do, you just need to look carefully at the supported voltages of each.

## And Beyond
There is quite a bit more I want to do with this chromebook. I'll post an update if I get around to these:

* Hack the GBB flags to remove the annoying [[[[Ctrl]]+[[D]]]] bootup
* Replace the [bootloader?!](https://libreboot.org/docs/install/chromebooks.html)
* Figure out a better system key binding/rebinding method than `acpid`
* Figure out a "better" remote desktop resizing
* Integrate my system changes into a debootstrap builder script
* A coat of spraypaint

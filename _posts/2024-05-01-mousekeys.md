---
title: Who Killed My Mousekeys?
layout: article
category: blog
description: Solving an annoying whodunnit
---
## Who killed my mousekeys?

I have been using Linux on an old chromebook that's served me really well as a thin client/SSH machine.
There are a lot of interesting problems to solve to make it as useful as possible, and just one of them is the touchpad.
The touchpad is just really awful to use. Scrolling and moving the cursor is okay, but clicking and right-clicking is really difficult.

So I was really glad to find I could use key combinations to emulate the mouse pointer buttons instead.
(I originally found this method in a blog post specifically about a chromebook but I can't seem to find it anymore to link to it.)

`~/.xmodmap`:
```
! Remap "Search" Chromebook key (Left of 'a', where capslock would be) from Super to Mode_switch
clear mod4
clear mod5
keycode 133 = Mode_switch
add mod4 = Mode_switch

! Use Mode_switch for special bindings
! Pointer_Button requires mousekeys enabled with `xkbset m`
keycode 38 = a A Pointer_Button1 Pointer_Button1
keycode 39 = s S Pointer_Button2 Pointer_Button2
keycode 40 = d D Pointer_Button3 Pointer_Button3
keycode 113 = Left Left Home Home
keycode 114 = Right Right End End
keycode 111 = Up Up Page_Up Page_Up
keycode 116 = Down Down Page_Down Page_Down
```

`~/.xinitrc`
```
[ -f ~/.Xmodmap ] && xmodmap ~/.Xmodmap

# Enable mousekeys so xmodmap bindings can use them
# Don't let mousekeys setting "expire"
xkbset exp "=mousekeys"
xkbset mousekeys
```

There is a special "Search" key on my chromebook in the place of the capslock that is a perfect place for the "Mode_switch" key. "Mode_switch" is easiest way to set up [advanced remaps in xmodmap](https://wiki.archlinux.org/title/xmodmap). The mapping for each keycode is `keycode <keycode> = Key Shift+Key Mode_switch+Key Mode_switch+Shift+Key`. So when `a` is pressed its just `a`, `Shift+a` results in `A`, and `Mode_switch+a` results in a left click. Likewise `s` is a middle-click and `d` is a right-click.

**This is so incredibly useful that I can't live without it.**
It feels very natural to handle the clicks with my left hand and control the cursor position with my right.
I'll install this binding on any laptop I'll ever use. I was thinking of enabling this even on my couch gaming PC that I sometimes control with a [K400 keyboard](https://www.logitech.com/en-us/products/keyboards/k400-plus-touchpad-keyboard.920-007119.html).
CapsLock sucks anyway, its a worthwhile sacrifice.

But this method has a problem.
You need "Mouse Keys" enabled in your X session, which can turn off "randomly".
When I first encountered this I looked online and found [this answer on stackexchange](https://askubuntu.com/a/1413625). If you just have `xkbset m` in your `.xinitrc` above then by default that setting will "expire" after some time in a perfectly infuriating manner. You need `xkbset exp "=mousekeys"` to turn off the expiry.

That mostly solves the issue, but I noticed recently I was still losing my mousekeys randomly.
Re-running `xkbset m` always solves the issue for a time.
```
xkbset q exp | grep Mouse
	Upon Expiry Mouse-Keys will be: Unchanged
	Upon Expiry Mouse-Keys Acceleration will be: Unchanged
xkbset q | grep "Mouse-Keys ="
	Mouse-Keys = Off
```
What is going on? It's not expiring, it's just losing the mousekeys setting seemingly out of nowhere.

The easy solution at this point would be to just make a little service that runs `xkbset mousekeys` in a loop and [move on with my life](https://xkcd.com/1495/).
But goddamnit I need to know. What the hell is killing my mousekeys?

It was difficult to associate exactly what I was doing when this happens; I needed a quicker feedback loop.
I use a shell script to handle the [status bar of my dwm desktop](https://dwm.suckless.org/status_monitor/), so I just put this in there:
```
while true; do
	if xkbset q | grep "Mouse-Keys = Off"; then
		s="WTF!"
	else
		s="perfectly normal things"
	fi
	xsetroot -name "${s}"
	sleep 1
done
```

This kept happening and driving me insane until one day I finally caught exactly what I was doing when I lost my mousekeys.
I was working in an SSH terminal working on a project involving QEMU as a testbed for kernel and init stuff.
As it turns out just `qemu-system-x86_64 -nographic`(in a remote session!) is enough to kill my mousekeys.

Some output of QEMU in my SSH session is being interpreted by my `xterm` terminal in such a way that it kills my mousekeys. Which feels deeply upsetting, that something can reach beyond the borders of both SSH and terminal and affect my desktop experience.
This smells like [ANSI escape code](https://en.wikipedia.org/wiki/ANSI_escape_code) insanity, lets narrow it down:
```
qemu-system-x86_64 -nographic >t
	Ctrl-A X
cat t  # kills mousekeys
head t # still a murderer
xxd t
	00000000: 1b63 1b5b 3f37 6c1b 5b32 4a1b 5b30 6d53  .c.[?7l.[2J.[0mS
head -c 2 t # Turns out just the first two bytes are necessary to kill
head -c 2 t >kill_mousekeys
cat kill_mousekeys # does what it says on the tin
```
The sequence `1b63` is killing my mousekeys.
`1b` is the normal escape code character, often referred to as `ESC` when describing escape control codes.
`63` is ASCII `c`, so this is just `ESC c`.
The [control sequences for xterm](https://www.xfree86.org/current/ctlseqs.html) lists this as `ESC c Full Reset (RIS)`.
Like most control sequences, this dates back to the [VT100 Terminal](https://vt100.net/docs/vt510-rm/RIS.html) that `xterm` is emulating.

So a "Full Reset" is killing my mousekeys.
Sure enough `reset` does the same thing.
I could have just started there. *Sigh*.
Already a better solution presents itself: Just don't use `xterm`.
Sure enough [suckless terminal](https://st.suckless.org/) doesn't have the issue.
I have used `st` in the past and found it a little glitchy, but I think I'll give it another shot thanks to this madness.

But that isn't very satisfying is it?
Can we fix `xterm`?

I built `xterm` from [sources](https://invisible-island.net/xterm/) and starting digging for the responsible code.
Searching for "RIS" led me to the function `ReallyReset` in `charproc.c`.
It's a big function that does a lot of things.
I ended up just putting in early `return`s at different spots, building, and testing for the the presense of the mousekeys reset.

I finally traced it down to a call to `xtermClearLEDs` in `scrollbar.c`.
`xtermClearLEDs` is also called in two other places, all #ifdef guarded by `OPT_SCROLL_LOCK`.
The problem is twofold:
1. The default xterm "reset" behavior includes resetting NumLock, CapsLock, and ScrollLock. i.e. The LEDs on your typical keyboard.
2. The function for clearing those LEDs takes a nuclear approach and ends up wiping all Keyboard Controls, including mousekeys. I guess mouse keys is effectually a kind of Lock or LED?

As it turns out, yes. The [xset](https://linux.die.net/man/1/xset) utility can enable/disable "leds" 1-32. With some experimentation I found `xset led 14` is the equivalent of `xkbset mousekeys`. So "mousekeys" is an "led", and it gets cleared like every other "led".

It feels like there is a bug in `xtermClearLEDs`, though. It's only written in the context of the normal three.
But honestly I would prefer the normal locks to not reset either, that also seems like annoying and unexpected behavior.
Why is xterm designed like this?

Clearing the LEDs as a result of an [RIS](https://vt100.net/docs/vt510-rm/RIS.html) reset basically only makes sense in the context this was originally designed for in 1978.
The [VT100 keyboard had 4 LEDs on the keyboard](https://vt100.net/docs/vt100-ug/chapter3.html) that were general purpose and toggled via escape codes.
We don't have a modern equivalent to these. We should bring them back. It would be neat.

It also had an "Alternate Keypad Mode" that functioned like NumLock that would have been reset. CapsLock [physically locked into one of two states on the keyboard](https://deskthority.net/wiki/DEC_VT100) itself, so that would *not* have been reset. And lastly it had a "NO SCROLL" key that had the effect of freezing the screen when active.

"NO SCROLL" would evolve into ScrollLock, and I believe terminal emulators try to emulate it by pausing autoscrolling when its active.
I believe that's the primary purpose of the code gated by `OPT_SCROLL_LOCK` in xterm is to emulate that behavior. As to why numlock and capslock get gated by the scroll feature, who knows.

The [Linux VT](https://en.wikipedia.org/wiki/Virtual_console) equivalent of controlling the LEDs is done with the [setleds](https://linux.die.net/man/1/setleds) tool.
The state of NumLock, CapsLock, and ScrollLock are actually specific for each VT.
And `reset` there also has the effect of clearing these "LEDs".
Already I think that's a bit of a hairy re-interpretation, or at least its pretty confusing to refer to them as LEDs rather than Locks or Modes.

But now we can see the root of the problem with `xterm`.
Resetting the Lock states makes sense (if you squint) in a VT because each VT gets its own personal set of Lock states.
But `xterm` adopted the closest equivalent of this behavior without considering that it shares these states with many other applications.
If `xterm` managed its own Lock states independent of the other applications in the X session maybe this would be acceptable behavior.
But `xterm` is messing with the Lock states of the whole X session, 
including other instances of `xterm`, browsers, calculators, whatever.

So there is *definiteley* a bug in `xtermClearLEDs`.
1. It probably shouldn't be clearing beyond the standard three locks.
2. I don't think it has any business clearing these locks at all!
Not unless it could manage its own "LEDs" indepedent of all other applications.

The best fix then is to neuter `xtermClearLEDs`:
```
void
xtermClearLEDs(TScreen *screen)
{
	// No. Don't do any of this. Bad.
	return;

    Display *dpy = screen->display;
    XKeyboardControl values;

    TRACE(("xtermClearLEDs\n"));
#ifdef HAVE_XKBQUERYEXTENSION
    ShowScrollLock(screen, False);
#endif

	// this seems like a bug, its probably meant to only clear Num/Caps/Scroll
    memset(&values, 0, sizeof(values));
    XChangeKeyboardControl(dpy, KBLedMode, &values);
}
```
You could also choose to disable the entire `OPT_SCROLL_LOCK` feature, though weirdly it isn't exposed by the configure script.

Who killed my mousekeys?
It was `xterm`, in the scrollbar code, with overbroad interpretation of decades-old escape sequences!
It's a clever murder weapon, I wouldn't be surprised if there is a dangerous-as-hell CVE or two lurking in those waters.

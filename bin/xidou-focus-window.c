/* Forces real X11 input focus onto a mapped, viewable
 * _NET_WM_WINDOW_TYPE_DOCK top-level window matching the exact
 * width/height given on argv[1]/argv[2].
 *
 * Exists because Quickshell's PanelWindow.focusable (the documented,
 * intended lever for exactly this) does not appear to actually request
 * X input focus on this system's X11 backend — verified empirically: with
 * focusable: true set, XGetInputFocus never reports anything but the root
 * window after a panel is shown, and neither Window.requestActivate() nor
 * reaching into ProxyWindowBase's _backingWindow for it produced any
 * effect either. A direct XSetInputFocus from an external process, by
 * contrast, was confirmed to work and to persist reliably. dwm itself is
 * uninvolved here: the target windows are the shell's own unmanaged
 * _NET_WM_WINDOW_TYPE_DOCK panels (see manage() in dwm/dwm.c), which never
 * go through dwm's focus()/setfocus() machinery at all.
 *
 * Matches by mapped size rather than a raw window ID or title, since
 * PanelWindow exposes neither an X11 window id nor a title property to
 * QML (title only exists on Quickshell's separate FloatingWindow type) —
 * every Xidou panel uses a distinct fixed size, so this is unambiguous in
 * practice without needing any extra QML-side plumbing. */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>

static Window
findwindow(Display *dpy, Atom wtype_atom, Atom dock_atom, int want_w, int want_h)
{
	Window root_ret, parent_ret, *children = NULL;
	unsigned int nchildren = 0;
	Window found = None;

	if (!XQueryTree(dpy, DefaultRootWindow(dpy), &root_ret, &parent_ret, &children, &nchildren))
		return None;

	for (unsigned int i = 0; i < nchildren && found == None; i++) {
		Atom actual;
		int format;
		unsigned long nitems, bytes_after;
		unsigned char *prop = NULL;

		XGetWindowProperty(dpy, children[i], wtype_atom, 0, 1, False, XA_ATOM,
			&actual, &format, &nitems, &bytes_after, &prop);
		int isdock = (nitems > 0 && prop && *(Atom *)prop == dock_atom);
		if (prop)
			XFree(prop);
		if (!isdock)
			continue;

		XWindowAttributes wa;
		if (!XGetWindowAttributes(dpy, children[i], &wa))
			continue;
		if (wa.map_state == IsViewable && wa.width == want_w && wa.height == want_h)
			found = children[i];
	}

	if (children)
		XFree(children);

	return found;
}

int
main(int argc, char **argv)
{
	if (argc != 3) {
		fprintf(stderr, "usage: %s <width> <height>\n", argv[0]);
		return 1;
	}

	int want_w = atoi(argv[1]);
	int want_h = atoi(argv[2]);

	Display *dpy = XOpenDisplay(NULL);
	if (!dpy) {
		fprintf(stderr, "xidou-focus-window: cannot open display\n");
		return 1;
	}

	Atom wtype_atom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
	Atom dock_atom = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);

	Window target = findwindow(dpy, wtype_atom, dock_atom, want_w, want_h);
	if (target == None) {
		fprintf(stderr, "xidou-focus-window: no mapped dock window sized %dx%d\n", want_w, want_h);
		XCloseDisplay(dpy);
		return 1;
	}

	XSetInputFocus(dpy, target, RevertToPointerRoot, CurrentTime);
	XFlush(dpy);
	XCloseDisplay(dpy);
	return 0;
}

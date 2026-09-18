/* See LICENSE file for copyright and license details. */

/* appearance */
static const unsigned int borderpx  = 1;        /* border pixel of windows */
static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 0;        /* 0 means no bar; Xidou's Quickshell bar owns this space */
static const int topbar             = 1;        /* 0 means bottom bar */
static const char *fonts[]          = { "monospace:size=10" };
static const char dmenufont[]       = "monospace:size=10";
static const char col_gray1[]       = "#222222";
static const char col_gray2[]       = "#444444";
static const char col_gray3[]       = "#bbbbbb";
static const char col_gray4[]       = "#eeeeee";
static const char col_cyan[]        = "#005577";
static const char *colors[][3]      = {
	/*               fg         bg         border   */
	[SchemeNorm] = { col_gray3, col_gray1, col_gray2 },
	[SchemeSel]  = { col_gray4, col_cyan,  col_cyan  },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class      instance    title       tags mask     isfloating   monitor */
	{ "Gimp",     NULL,       NULL,       0,            1,           -1 },
	{ "Firefox",  NULL,       NULL,       1 << 8,       0,           -1 },
};

/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

#include "fibonacci.c"
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[\\]",     dwindle },    /* first entry is default */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* key definitions */
#define MODKEY Mod4Mask /* Super, to match the super+<key> convention in config.toml and MangoWM */
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont, "-nb", col_gray1, "-nf", col_gray3, "-sb", col_cyan, "-sf", col_gray4, NULL };
static const char *termcmd[]  = { "kitty", NULL }; /* only terminal emulator installed on this system */

/* Media keys go straight to wpctl (WirePlumber's own CLI) against the
 * default sink, the same underlying PipeWire state Quickshell's Volume
 * module already reads/writes reactively for click-to-mute — no dwm-ipc
 * command needed, since dwm-ipc only knows about window-manager state. */
static const char *volraisecmd[] = { "wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+", NULL };
static const char *vollowercmd[] = { "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-", NULL };
static const char *volmutecmd[]  = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle", NULL };

/* super+ctrl+<arrow>: resizeclientkey()'s argument — a discrete {dx,dy} nudge
 * per keypress, matching MangoWM's resizewin as literally as dwm's own
 * resize() allows (see resizeclientkey() in dwm.c for the tiled-client
 * caveat: the next arrange() overrides it, same as resizemouse() already
 * has). */
static const int resizeleft[2]  = { -30, 0 };
static const int resizeright[2] = { 30, 0 };
static const int resizeup[2]    = { 0, -30 };
static const int resizedown[2]  = { 0, 30 };

/* ctrl+<arrow>: MPRIS control. No CLI player controller (playerctl etc.) is
 * installed, and none is needed — Quickshell's Media bar module already
 * holds a live MprisPlayer with next()/previous()/togglePlaying(), so this
 * goes through the same shell IPC as panel toggles instead of a new
 * external dependency; see quickshell/services/PanelState.qml's sibling
 * Mpris IpcHandler in shell.qml. */
static const char *mprisnextcmd[]      = { "xidou", "msg", "mpris", "next", NULL };
static const char *mprisprevcmd[]      = { "xidou", "msg", "mpris", "previous", NULL };
static const char *mprisplaypausecmd[] = { "xidou", "msg", "mpris", "playPause", NULL };

/* Launcher toggle goes through `xidou msg`, the CLI/IPC surface CLAUDE.md's
 * architecture section calls for (mirrors MangoWM's `noctalia msg
 * panel-toggle launcher`) — dwm still owns the bind, it just hands off to
 * the shell over Quickshell's own IPC rather than dwm-ipc, since this is
 * shell UI state, not window-manager state. */
static const char *launchertogglecmd[] = { "xidou", "msg", "panel-toggle", "launcher", NULL };

/* Reserved binds for panels that don't exist yet (Phase 4/5/6/7) — wired to
 * their `xidou msg` command now, even though nothing listens on the shell
 * side yet, so they start working automatically once each panel is built,
 * with zero dwm-side changes needed then. Target/function names here are
 * provisional placeholders; the real IpcHandler each phase adds is free to
 * settle on different naming — nothing depends on these being "correct"
 * before something is listening. */
static const char *controlcentertogglecmd[] = { "xidou", "msg", "panel-toggle", "control-center", NULL }; /* Phase 5 */
static const char *settingstogglecmd[]      = { "xidou", "msg", "settings", "toggle", NULL };
static const char *clipboardtogglecmd[]     = { "xidou", "msg", "panel-toggle", "clipboard", NULL }; /* Phase 7 */
static const char *windowswitchercmd[]      = { "xidou", "msg", "windowswitcher", "toggle", NULL }; /* future overview feature */
static const char *notificationdndcmd[]     = { "xidou", "msg", "notifications", "toggleDnd", NULL }; /* Phase 4 */
static const char *sessiontogglecmd[]       = { "xidou", "msg", "panel-toggle", "session", NULL }; /* Phase 7 */
static const char *sessionlockcmd[]         = { "xidou", "msg", "session", "lock", NULL }; /* Phase 7 */
static const char *wallpapertogglecmd[]     = { "xidou", "msg", "panel-toggle", "wallpaper", NULL }; /* Phase 6 */
static const char *screenshotfullcmd[]      = { "xidou", "msg", "screenshot", "fullscreen", NULL }; /* Phase 7 */
static const char *screenshotregioncmd[]    = { "xidou", "msg", "screenshot", "region", NULL }; /* Phase 7 */

static const Key keys[] = {
	/* modifier                     key        function          argument */
	{ MODKEY,                       XK_p,      spawn,            {.v = dmenucmd } },
	{ MODKEY,                       XK_Return, spawn,            {.v = termcmd } },
	{ MODKEY|ShiftMask,             XK_Return, spawn,            {.v = termcmd } },
	{ MODKEY,                       XK_d,      spawn,            {.v = launchertogglecmd } },
	{ 0,                            XF86XK_AudioRaiseVolume, spawn, {.v = volraisecmd } },
	{ 0,                            XF86XK_AudioLowerVolume, spawn, {.v = vollowercmd } },
	{ 0,                            XF86XK_AudioMute,        spawn, {.v = volmutecmd } },
	{ ControlMask,                  XK_Right,  spawn,            {.v = mprisnextcmd } },
	{ ControlMask,                  XK_Left,   spawn,            {.v = mprisprevcmd } },
	{ ControlMask,                  XK_Down,   spawn,            {.v = mprisplaypausecmd } },
	{ MODKEY|ControlMask,           XK_Left,   resizeclientkey,  {.v = resizeleft } },
	{ MODKEY|ControlMask,           XK_Right,  resizeclientkey,  {.v = resizeright } },
	{ MODKEY|ControlMask,           XK_Up,     resizeclientkey,  {.v = resizeup } },
	{ MODKEY|ControlMask,           XK_Down,   resizeclientkey,  {.v = resizedown } },
	{ MODKEY,                       XK_b,      togglebar,        {0} },
	{ MODKEY,                       XK_j,      focusstack,       {.i = +1 } },
	{ MODKEY,                       XK_k,      focusstack,       {.i = -1 } },
	{ MODKEY,                       XK_i,      incnmaster,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_i,      incnmaster,       {.i = -1 } },
	{ MODKEY,                       XK_h,      setmfact,         {.f = -0.05} },
	{ MODKEY|ControlMask,           XK_l,      setmfact,         {.f = +0.05} }, /* moved off super+l for session-lock */
	{ MODKEY,                       XK_q,      killclient,       {0} },
	{ MODKEY|ControlMask,           XK_r,      setlayout,        {.v = &layouts[0]} }, /* moved off super+r */
	{ MODKEY|ControlMask,           XK_t,      setlayout,        {.v = &layouts[1]} }, /* moved off super+t */
	{ MODKEY|ControlMask,           XK_f,      setlayout,        {.v = &layouts[2]} }, /* moved off super+f */
	{ MODKEY,                       XK_m,      setlayout,        {.v = &layouts[3]} },
	{ MODKEY,                       XK_space,  setlayout,        {0} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating,   {0} },
	{ MODKEY,                       XK_f,      togglefloating,   {0} },
	{ MODKEY,                       XK_t,      togglefullscreen, {0} },
	{ MODKEY,                       XK_0,      view,             {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,      tag,              {.ui = ~0 } },
	{ MODKEY,                       XK_period, focusmon,         {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_period, tagmon,           {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,  tagmon,           {.i = -1 } },
	{ MODKEY,                       XK_x,      cycleview,        {.i = +1 } },
	{ MODKEY,                       XK_z,      cycleview,        {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_x,      cycletag,         {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_z,      cycletag,         {.i = -1 } },
	TAGKEYS(                        XK_1,                      0)
	TAGKEYS(                        XK_2,                      1)
	TAGKEYS(                        XK_3,                      2)
	TAGKEYS(                        XK_4,                      3)
	TAGKEYS(                        XK_5,                      4)
	TAGKEYS(                        XK_6,                      5)
	TAGKEYS(                        XK_7,                      6)
	TAGKEYS(                        XK_8,                      7)
	TAGKEYS(                        XK_9,                      8)
	{ MODKEY|ShiftMask,             XK_e,      quit,             {0} }, /* moved off super+shift+q */
	/* reserved for panels not built yet (Phase 4/5/6/7) — see the command
	 * arrays above */
	{ MODKEY,                       XK_s,      spawn,            {.v = controlcentertogglecmd } },
	{ MODKEY,                       XK_comma,  spawn,            {.v = settingstogglecmd } },
	{ MODKEY,                       XK_v,      spawn,            {.v = clipboardtogglecmd } },
	{ MODKEY,                       XK_Tab,    spawn,            {.v = windowswitchercmd } },
	{ MODKEY,                       XK_n,      spawn,            {.v = notificationdndcmd } },
	{ MODKEY,                       XK_Escape, spawn,            {.v = sessiontogglecmd } },
	{ MODKEY,                       XK_l,      spawn,            {.v = sessionlockcmd } },
	{ MODKEY,                       XK_y,      spawn,            {.v = wallpapertogglecmd } },
	{ 0,                            XK_Print,  spawn,            {.v = screenshotfullcmd } },
	{ ControlMask,                  XK_Print,  spawn,            {.v = screenshotregioncmd } },
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[3]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
	/* super+scroll: cycle tag, regardless of what's under the cursor —
	 * see grabrootbuttons() in dwm.c for how ClkRootWin gets grabbed
	 * globally on root rather than scoped to the bar/a client window like
	 * every other entry above. Button4 = scroll up, Button5 = scroll
	 * down, matching super+z (prev) / super+x (next). */
	{ ClkRootWin,           MODKEY,         Button4,        cycleview,      {.i = -1 } },
	{ ClkRootWin,           MODKEY,         Button5,        cycleview,      {.i = +1 } },
	{ ClkRootWin,           MODKEY|ShiftMask, Button4,      cycletag,       {.i = -1 } },
	{ ClkRootWin,           MODKEY|ShiftMask, Button5,      cycletag,       {.i = +1 } },
};

static const char *ipcsockpath = "/tmp/dwm.sock";
static IPCCommand ipccommands[] = {
  IPCCOMMAND(  view,                1,      {ARG_TYPE_UINT}   ),
  IPCCOMMAND(  toggleview,          1,      {ARG_TYPE_UINT}   ),
  IPCCOMMAND(  tag,                 1,      {ARG_TYPE_UINT}   ),
  IPCCOMMAND(  toggletag,           1,      {ARG_TYPE_UINT}   ),
  IPCCOMMAND(  tagmon,              1,      {ARG_TYPE_UINT}   ),
  IPCCOMMAND(  focusmon,            1,      {ARG_TYPE_SINT}   ),
  IPCCOMMAND(  focusstack,          1,      {ARG_TYPE_SINT}   ),
  IPCCOMMAND(  zoom,                1,      {ARG_TYPE_NONE}   ),
  IPCCOMMAND(  incnmaster,          1,      {ARG_TYPE_SINT}   ),
  IPCCOMMAND(  killclient,          1,      {ARG_TYPE_SINT}   ),
  IPCCOMMAND(  togglefloating,      1,      {ARG_TYPE_NONE}   ),
  IPCCOMMAND(  setmfact,            1,      {ARG_TYPE_FLOAT}  ),
  IPCCOMMAND(  setlayoutsafe,       1,      {ARG_TYPE_PTR}    ),
  IPCCOMMAND(  quit,                1,      {ARG_TYPE_NONE}   )
};


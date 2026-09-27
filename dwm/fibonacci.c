/* Gaps: outer (mon->gappoh, screen edge <-> window) and inner (mon->gappih,
 * window <-> window), both settable at runtime via the setgappih/setgappoh
 * IPC commands (see dwm.c) -- session/xidou-xinitrc pushes config.toml's
 * [layout] values in once at session start.
 *
 * This algorithm still computes the exact same gapless (touching) rectangles
 * it always did; gaps are applied as a pure geometric transform on top of
 * that, in two steps, rather than by threading gap math through the tiling
 * logic itself:
 *
 *   1. The whole tiling area is shrunk ONCE, before any window geometry is
 *      computed, by (gappoh - gappih/2) on every side (clamped to 0 if
 *      gappih/2 > gappoh).
 *   2. Every individual window's final rect is then shrunk by gappih/2 on
 *      ALL FOUR of its own sides, unconditionally -- regardless of whether
 *      a given side touches the screen edge or a neighboring window.
 *
 * Why this hits the exact requested pixel values despite step 2 not knowing
 * which sides are "outer" vs "inner": a screen-edge side gets
 * (gappoh - gappih/2) from step 1 plus gappih/2 from step 2 = gappoh
 * exactly. A side shared between two windows gets gappih/2 contributed
 * independently by each of the two windows on their own touching side =
 * gappih exactly. No per-edge classification needed -- this works for any
 * layout produced by this recursive splitting, not just simple grids.
 * (Integer division on an odd gappih can round the inner gap down by at
 * most 1px; not worth the extra bookkeeping to avoid for a cosmetic
 * feature.)
 */
void
fibonacci(Monitor *mon, int s) {
	unsigned int i, n, nx, ny, nw, nh, oh, ih2;
	Client *c;

	for(n = 0, c = nexttiled(mon->clients); c; c = nexttiled(c->next), n++);
	if(n == 0)
		return;

	oh = mon->gappoh > mon->gappih / 2 ? mon->gappoh - mon->gappih / 2 : 0;
	ih2 = mon->gappih / 2;

	nx = mon->wx + oh;
	ny = 0;
	nw = mon->ww - 2 * oh;
	nh = mon->wh - 2 * oh;

	for(i = 0, c = nexttiled(mon->clients); c; c = nexttiled(c->next)) {
		if((i % 2 && nh / 2 > 2 * c->bw)
		   || (!(i % 2) && nw / 2 > 2 * c->bw)) {
			if(i < n - 1) {
				if(i % 2)
					nh /= 2;
				else
					nw /= 2;
				if((i % 4) == 2 && !s)
					nx += nw;
				else if((i % 4) == 3 && !s)
					ny += nh;
			}
			if((i % 4) == 0) {
				if(s)
					ny += nh;
				else
					ny -= nh;
			}
			else if((i % 4) == 1)
				nx += nw;
			else if((i % 4) == 2)
				ny += nh;
			else if((i % 4) == 3) {
				if(s)
					nx += nw;
				else
					nx -= nw;
			}
			if(i == 0)
			{
				if(n != 1)
					nw = (mon->ww - 2 * oh) * mon->mfact;
				ny = mon->wy + oh;
			}
			else if(i == 1)
				nw = (mon->ww - 2 * oh) - nw;
			i++;
		}
		resize(c, nx + ih2, ny + ih2, nw - 2 * c->bw - 2 * ih2, nh - 2 * c->bw - 2 * ih2, False);
	}
}

void
dwindle(Monitor *mon) {
	fibonacci(mon, 1);
}

void
spiral(Monitor *mon) {
	fibonacci(mon, 0);
}

"""迷宫生成器（可复用）：按种子生成「真正的迷宫」格子图，给楼层生成脚本（如 gen_floor08.py 的夜迷宫）摆东西用。

结构：迷宫单元 = 2x2 的地面 + 1 格墙（走廊两格宽）。
  1. 随机深度优先在单元格上挖出一棵走廊树（岔路、死路多）；
  2. 再随机打通一些墙做回环（loops 比例）；
  3. 挖几个小房间（几个单元连成一片）；
  4. 起点在左下角、出口在离起点最远的单元（BFS 距离）。
呼吸墙（breathing）：成对的墙段 (A, B)，A = 现在打通的一段走廊、B = 现在封着的一段墙；心跳时 A 封上、B 打开。
  只选「两种状态下从起点都能走到出口和所有关键点」的墙段对（BFS 检查）。

用法（在别的生成脚本里）：
    from maze_gen import Maze
    mz = Maze(cols, rows, seed=1, loops=0.12, rooms=3, breathing=6)
    mz.grid                    # [[ '#' / '.' ]]，大小 (rows*3+1) x (cols*3+1)
    mz.start, mz.exit          # 起点 / 出口单元的左上地面格 (x, y)
    mz.cell_floor(c)           # 单元 c 的 4 个地面格
    mz.dead_ends               # 死路单元（离主路越远越靠前）
    mz.main_path               # 起点到出口的单元路线
    mz.rooms                   # [[单元, ...], ...]
    mz.breathing               # [{"a": [(x,y)...], "b": [(x,y)...]}, ...]（a 现在是地面、b 现在是墙）
    mz.reachable(open_cells, closed_cells, frm, targets)  # 检查用
"""
import random
from collections import deque

STEP = 3


class Maze:
    def __init__(self, cols, rows, seed=1, loops=0.12, rooms=3, breathing=6):
        self.cols, self.rows = cols, rows
        self.rng = random.Random(seed)
        self.w, self.h = cols * STEP + 1, rows * STEP + 1
        self.grid = [["#"] * self.w for _ in range(self.h)]
        self.links = set()   # 打通的单元对 frozenset({c1, c2})
        self._carve_tree()
        self._add_loops(loops)
        self.rooms = self._add_rooms(rooms)
        for c in self.all_cells():
            for (x, y) in self.cell_floor(c):
                self.grid[y][x] = "."
        for pair in self.links:
            for (x, y) in self.link_cells(*sorted(pair)):
                self.grid[y][x] = "."
        self.start_cell = (0, rows - 1)
        dist = self._cell_dist(self.start_cell)
        self.exit_cell = max(dist, key=lambda c: dist[c])
        self.start = self.cell_floor(self.start_cell)[0]
        self.exit = self.cell_floor(self.exit_cell)[0]
        self.main_path = self._cell_path(self.start_cell, self.exit_cell)
        on_main = set(self.main_path)
        ends = [c for c in self.all_cells() if self.degree(c) == 1 and c not in (self.start_cell, self.exit_cell)]
        main_dist = self._multi_dist(self.main_path)
        self.dead_ends = sorted(ends, key=lambda c: -main_dist.get(c, 0))
        self.branch_cells = [c for c in self.all_cells() if c not in on_main]
        self.breathing = self._pick_breathing(breathing)

    # -------------------------------------------------------------- 单元 / 格子
    def all_cells(self):
        return [(cx, cy) for cy in range(self.rows) for cx in range(self.cols)]

    def cell_floor(self, c):
        x0, y0 = c[0] * STEP + 1, c[1] * STEP + 1
        return [(x0, y0), (x0 + 1, y0), (x0, y0 + 1), (x0 + 1, y0 + 1)]

    def cell_center(self, c):
        """单元 4 个地面格里靠左上的那个（摆东西用）。"""
        return self.cell_floor(c)[0]

    def link_cells(self, a, b):
        """两个相邻单元之间那段墙（2 格）。"""
        (ax, ay), (bx, by) = a, b
        if ay == by:
            x = max(ax, bx) * STEP
            y0 = ay * STEP + 1
            return [(x, y0), (x, y0 + 1)]
        y = max(ay, by) * STEP
        x0 = ax * STEP + 1
        return [(x0, y), (x0 + 1, y)]

    def neighbors(self, c):
        cx, cy = c
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cx + dx, cy + dy)
            if 0 <= n[0] < self.cols and 0 <= n[1] < self.rows:
                yield n

    def linked(self, a, b):
        return frozenset((a, b)) in self.links

    def degree(self, c):
        return sum(1 for n in self.neighbors(c) if self.linked(c, n))

    # -------------------------------------------------------------- 生成
    def _carve_tree(self):
        start = (0, self.rows - 1)
        seen = {start}
        stack = [start]
        while stack:
            c = stack[-1]
            opts = [n for n in self.neighbors(c) if n not in seen]
            if not opts:
                stack.pop()
                continue
            n = self.rng.choice(opts)
            self.links.add(frozenset((c, n)))
            seen.add(n)
            stack.append(n)

    def _add_loops(self, ratio):
        walls = [(c, n) for c in self.all_cells() for n in self.neighbors(c) if c < n and not self.linked(c, n)]
        self.rng.shuffle(walls)
        for c, n in walls[:int(len(walls) * ratio)]:
            self.links.add(frozenset((c, n)))

    def _add_rooms(self, count):
        rooms = []
        tries = 0
        while len(rooms) < count and tries < 200:
            tries += 1
            w, h = self.rng.choice([(2, 2), (3, 2), (2, 3)])
            cx = self.rng.randrange(1, max(2, self.cols - w - 1))
            cy = self.rng.randrange(1, max(2, self.rows - h - 1))
            cells = [(cx + i, cy + j) for i in range(w) for j in range(h)]
            if any(c in r for r in rooms for c in cells):
                continue
            for c in cells:
                for n in self.neighbors(c):
                    if n in cells:
                        self.links.add(frozenset((c, n)))
            # 房间内部的墙角也打通（变成一整片）
            for i in range(w - 1):
                for j in range(h - 1):
                    x, y = (cx + i + 1) * STEP, (cy + j + 1) * STEP
                    self.grid[y][x] = "."
            rooms.append(cells)
        for r in rooms:
            for c in r:
                for (x, y) in self.cell_floor(c):
                    self.grid[y][x] = "."
        return rooms

    # -------------------------------------------------------------- 距离 / 路线
    def _cell_dist(self, frm):
        dist = {frm: 0}
        q = deque([frm])
        while q:
            c = q.popleft()
            for n in self.neighbors(c):
                if self.linked(c, n) and n not in dist:
                    dist[n] = dist[c] + 1
                    q.append(n)
        return dist

    def _multi_dist(self, sources):
        dist = {s: 0 for s in sources}
        q = deque(sources)
        while q:
            c = q.popleft()
            for n in self.neighbors(c):
                if self.linked(c, n) and n not in dist:
                    dist[n] = dist[c] + 1
                    q.append(n)
        return dist

    def _cell_path(self, a, b):
        prev = {a: None}
        q = deque([a])
        while q:
            c = q.popleft()
            if c == b:
                break
            for n in self.neighbors(c):
                if self.linked(c, n) and n not in prev:
                    prev[n] = c
                    q.append(n)
        path, c = [], b
        while c is not None:
            path.append(c)
            c = prev[c]
        return path[::-1]

    # -------------------------------------------------------------- 格子层面的连通检查
    def reachable(self, open_cells=(), closed_cells=(), frm=None, targets=()):
        """把 open_cells 当地面、closed_cells 当墙之后，从 frm 能不能走到所有 targets（格子坐标）。"""
        opened, closed = set(open_cells), set(closed_cells)

        def floor(x, y):
            if (x, y) in closed:
                return False
            if (x, y) in opened:
                return True
            return 0 <= x < self.w and 0 <= y < self.h and self.grid[y][x] == "."

        frm = frm or self.start
        seen = {frm}
        q = deque([frm])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in seen and floor(*n):
                    seen.add(n)
                    q.append(n)
        return all(t in seen for t in targets)

    def _pick_breathing(self, count):
        """呼吸墙对：A = 打通的一段（不在主路上更好），B = 附近封着的一段；两种状态都要能从起点走到出口。"""
        opened = [tuple(sorted(p)) for p in self.links]
        closed = [(c, n) for c in self.all_cells() for n in self.neighbors(c) if c < n and not self.linked(c, n)]
        room_cells = {c for r in self.rooms for c in r}
        self.rng.shuffle(opened)
        out, used = [], set()
        targets = [self.exit]
        for a in opened:
            if len(out) >= count:
                break
            if a[0] in room_cells or a[1] in room_cells or a[0] in used or a[1] in used:
                continue
            near = [b for b in closed if b[0] not in used and b[1] not in used
                    and abs(b[0][0] - a[0][0]) + abs(b[0][1] - a[0][1]) <= 2 and b != a]
            self.rng.shuffle(near)
            for b in near:
                ca, cb = self.link_cells(*a), self.link_cells(*b)
                state0 = self.reachable(open_cells=[], closed_cells=[], targets=targets)
                state1 = self.reachable(open_cells=cb, closed_cells=ca, targets=targets)
                if state0 and state1:
                    out.append({"a": ca, "b": cb})
                    used.update([a[0], a[1], b[0], b[1]])
                    break
        return out

    # -------------------------------------------------------------- 摆东西用
    def corridor_cells(self, exclude=()):
        """走廊里的单元（度为 2 的直道 / 拐角，不在房间里）。"""
        room_cells = {c for r in self.rooms for c in r}
        ex = set(exclude)
        return [c for c in self.all_cells() if self.degree(c) == 2 and c not in room_cells and c not in ex]

    def spread(self, cells, count):
        """从 cells 里挑 count 个尽量分散的。"""
        cells = list(cells)
        if not cells:
            return []
        picked = [self.rng.choice(cells)]
        while len(picked) < min(count, len(cells)):
            best = max((c for c in cells if c not in picked),
                       key=lambda c: min(abs(c[0] - p[0]) + abs(c[1] - p[1]) for p in picked))
            picked.append(best)
        return picked

    def text(self):
        return "\n".join("".join(r) for r in self.grid)

extends RefCounted
## 街上几间店的门面：每家都有夸张的招牌道具，而且会动。
##   造船厂：屋后停着两条船（旗子在飘），屋顶立着大锚，旁边的吊机吊着箱子晃
##   工坊：屋顶一个巨大的齿轮带着小齿轮转，烟囱冒烟，门边铁砧叮叮当当溅火星，墙上的管子漏蒸汽
##   服装店：屋顶一把会开合的大剪刀，屋檐挂彩旗，门上有条纹遮阳篷
##   渔具店：屋顶趴着一条摆尾巴的大鱼，伸出一根大钓竿钓着小鱼晃荡，门边的灯笼摇摆
## 全是用调色板里的颜色现画的，和 world.gd 一样借用 m（主节点）的绘制方法。

const Pal := preload("res://presentation/palette.gd")

var w          # World
var m

func _init(world) -> void:
	w = world
	m = world.m

func _gy() -> float:
	return float(w.GROUND_Y)

# ------------------------------------------------------------------ 小工具
func _r(x: float, y: float, wd: float, h: float, col: Color) -> void:
	m.draw_rect(Rect2(roundf(x), roundf(y), wd, h), col)

func _disc(cx: float, cy: float, rad: float, col: Color) -> void:
	var y := -int(rad)
	while y <= int(rad):
		var half := int(floor(sqrt(maxf(0.0, rad * rad - float(y * y)) + 0.25)))
		_r(cx - half, cy + y, half * 2 + 1, 1, col)
		y += 1

func _ell(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var y := -int(ry)
	while y <= int(ry):
		var k := 1.0 - float(y * y) / (ry * ry + 0.01)
		var half := int(floor(rx * sqrt(maxf(0.0, k)) + 0.5))
		_r(cx - half, cy + y, half * 2 + 1, 1, col)
		y += 1

## 齿轮：先画一圈描边，再画本体、齿、辐条和轴心。ang 是旋转角（弧度）。
func _gear(cx: float, cy: float, rad: float, teeth: int, ang: float, col: Color, dark: Color) -> void:
	for pass_i in 2:
		var c: Color = Pal.U_K if pass_i == 0 else col
		var grow := 1.0 if pass_i == 0 else 0.0
		_disc(cx, cy, rad + grow, c)
		for k in teeth:
			var a := ang + TAU * float(k) / float(teeth)
			var px := cx + cos(a) * (rad + 1.5)
			var py := cy + sin(a) * (rad + 1.5)
			var sz := 3.0 + grow * 2.0
			_r(px - sz / 2.0 + 0.5, py - sz / 2.0 + 0.5, sz, sz, c)
	_disc(cx, cy, rad * 0.62, dark)
	for k in 3:                                         # 三根辐条，让转动看得出来
		var a2 := ang + TAU * float(k) / 3.0
		m.pixel_line(Vector2(cx, cy), Vector2(roundf(cx + cos(a2) * rad * 0.9), roundf(cy + sin(a2) * rad * 0.9)), col)
	_disc(cx, cy, maxf(1.0, rad * 0.22), Pal.U_K)

## 烟 / 蒸汽：几团圆圆的小云往上飘、变淡、越飘越大。
func _smoke(x: float, y: float, t: int, n: int, period: int, col: Color, drift: float) -> void:
	for i in n:
		var ph := fposmod(float(t) / float(period) + float(i) / float(n), 1.0)
		var rad := 1.0 + ph * 3.0
		var a := (1.0 - ph) * 0.8
		_disc(x + sin(ph * 5.0 + float(i) * 2.0) * 2.0 + ph * drift, y - ph * 26.0, rad, Color(col, a))

## 旗：杆顶向右飘的三角旗，波浪一格一格抖。
func _flag(x: float, y: float, t: int, col: Color, length: int = 8) -> void:
	for i in length:
		var hh := maxi(1, 4 - i / 3)
		var wob := roundf(sin(float(t) / 160.0 - float(i) * 0.7) * 1.2)
		_r(x + 1 + i, y + wob, 1, hh, col)
	_r(x, y - 1, 1, 7, Pal.U_K)

# ------------------------------------------------------------------ 房子后面（先画，房子盖在上面）
func draw_behind(t: int) -> void:
	var gy := _gy()
	# 造船厂后院：两条停在木架上的船
	_boat(729.0, gy - 19.0, Pal.L_B, Pal.U_B, t, 0, 18.0)
	_boat(738.0, gy - 8.0, Pal.L_R, Pal.U_R, t, 1, 14.0)

func _boat(cx: float, base_y: float, hull: Color, hull_dark: Color, t: int, seed: int, mast_h: float) -> void:
	# 木架
	_r(cx - 11, base_y + 1, 3, 6, Pal.U_O)
	_r(cx + 8, base_y + 1, 3, 6, Pal.U_O)
	_r(cx - 14, base_y + 6, 28, 2, Pal.L_O)
	# 船壳：上宽下窄，船头（右）翘起
	var rows := [[-17, 19], [-17, 19], [-16, 18], [-15, 16], [-14, 15], [-12, 13], [-9, 10], [-6, 7]]
	for i in rows.size():
		var a: int = rows[i][0]
		var b: int = rows[i][1]
		_r(cx + a - 1, base_y - 6 + i - 1, b - a + 3, 1 if i > 0 else 1, Pal.U_K)
	_r(cx + rows[0][0] - 1, base_y - 7, rows[0][1] - rows[0][0] + 3, 1, Pal.U_K)
	for i in rows.size():
		var a2: int = rows[i][0]
		var b2: int = rows[i][1]
		_r(cx + a2, base_y - 6 + i, b2 - a2 + 1, 1, hull if i != 2 else Pal.L_W)
		if i >= 2:
			_r(cx + a2, base_y - 6 + i, b2 - a2 + 1, 1, hull_dark if i % 2 == 0 else hull)
	_r(cx + 17, base_y - 8, 2, 2, Pal.U_K)              # 船头翘起
	_r(cx + 16, base_y - 8, 2, 1, hull)
	# 桅杆、卷起的帆、旗
	var mx := cx + 2.0
	_r(mx, base_y - 6 - mast_h, 2, mast_h, Pal.U_O)
	_r(mx - 7, base_y - 6 - mast_h + 7, 16, 2, Pal.L_W)
	_r(mx - 7, base_y - 6 - mast_h + 9, 16, 1, Pal.L_A)
	_flag(mx + 1.0, base_y - 6 - mast_h - 2.0 + float(seed), t + seed * 400, Pal.L_R if seed == 0 else Pal.L_Y, 7)

# ------------------------------------------------------------------ 房子上面（后画，盖在房子前面）
func draw_over(t: int, dark: float) -> void:
	_shipyard(t)
	_workshop(t)
	_tailor(t)
	_tackle(t, dark)

func _shipyard(t: int) -> void:
	var gy := _gy()
	var y0 := gy - 60.0
	# 屋脊上的大锚
	var ax := 680.0
	var ay := y0 - 14.0
	_r(ax - 1, ay, 3, 20, Pal.U_K)
	_r(ax, ay + 1, 1, 18, Pal.L_A)
	_r(ax - 5, ay + 4, 11, 3, Pal.U_K)
	_r(ax - 4, ay + 5, 9, 1, Pal.L_A)
	_disc(ax, ay - 1.0, 3.0, Pal.U_K)
	_disc(ax, ay - 1.0, 1.0, Pal.U_W)
	m.pixel_line(Vector2(ax - 8, ay + 12), Vector2(ax - 1, ay + 18), Pal.U_K)
	m.pixel_line(Vector2(ax + 8, ay + 12), Vector2(ax + 1, ay + 18), Pal.U_K)
	m.pixel_line(Vector2(ax - 7, ay + 12), Vector2(ax - 1, ay + 17), Pal.L_A)
	m.pixel_line(Vector2(ax + 7, ay + 12), Vector2(ax + 1, ay + 17), Pal.L_A)
	_r(ax - 9, ay + 10, 3, 3, Pal.U_K)
	_r(ax + 7, ay + 10, 3, 3, Pal.U_K)
	# 屋顶一角的小旗
	_flag(657.0, y0 + 2.0, t, Pal.L_R, 9)
	# 右边的吊机：立柱 + 横臂 + 晃来晃去的货箱
	_r(709, y0 + 2, 3, int(gy - y0) - 2, Pal.U_O)
	_r(709, y0 + 2, 1, int(gy - y0) - 2, Pal.L_O)
	_r(709, y0 + 3, 22, 3, Pal.U_O)
	_r(709, y0 + 3, 22, 1, Pal.L_O)
	m.pixel_line(Vector2(711, y0 + 20), Vector2(720, y0 + 6), Pal.U_O)
	var sw := sin(float(t) / 650.0)
	var rope_len := 9.0 + 3.0 * sin(float(t) / 1700.0)
	var hx := 728.0 + sw * 3.0
	m.pixel_line(Vector2(728, y0 + 6), Vector2(roundf(hx), y0 + 6 + rope_len), Pal.U_K)
	_r(hx - 4, y0 + 6 + rope_len, 9, 8, Pal.U_K)
	_r(hx - 3, y0 + 7 + rope_len, 7, 6, Pal.L_O)
	_r(hx - 3, y0 + 9 + rope_len, 7, 1, Pal.U_O)
	_r(hx, y0 + 7 + rope_len, 1, 6, Pal.U_O)

func _workshop(t: int) -> void:
	var gy := _gy()
	var y0 := gy - 60.0
	var cx := 781.0
	var spin := float(t) / 1400.0
	# 大齿轮从屋顶冒出来，旁边咬着一个小的反着转
	_gear(760.0, y0 - 1.0, 7.0, 8, -spin * 2.2 + 0.2, Pal.L_Y, Pal.U_H)
	_gear(cx + 4.0, y0 - 5.0, 13.0, 12, spin, Pal.L_H, Pal.U_H)
	# 烟囱的烟（烟囱是房子贴图上的）
	_smoke(797.0, y0 + 1.0, t, 5, 3600, Pal.L_W, 6.0)
	# 墙上的管子，漏蒸汽
	_r(756, y0 + 26, 2, 22, Pal.U_A)
	_r(756, y0 + 26, 1, 22, Pal.L_A)
	_r(754, y0 + 46, 6, 3, Pal.U_A)
	_r(754, y0 + 46, 6, 1, Pal.L_A)
	if (t / 2400) % 2 == 0:
		_smoke(757.0, y0 + 25.0, t * 2, 4, 1800, Pal.U_W, -3.0)
	# 门边的铁砧 + 铁锤 + 火星
	var ax := 790.0
	var ay := gy - 9.0
	_r(ax - 1, ay + 6, 11, 3, Pal.U_K)
	_r(ax, ay + 6, 9, 2, Pal.U_O)
	_r(ax + 1, ay + 3, 7, 3, Pal.U_K)
	_r(ax + 2, ay + 3, 5, 2, Pal.U_A)
	_r(ax - 2, ay + 1, 13, 3, Pal.U_K)
	_r(ax - 1, ay + 1, 11, 2, Pal.L_A)
	_r(ax - 4, ay + 1, 3, 2, Pal.U_K)
	var cyc := t % 1300
	var swing := 0.0
	if cyc < 300:
		swing = 1.0 - float(cyc) / 300.0          # 抬起 → 砸下
	var hx := ax + 5.0 - 6.0 * swing
	var hy := ay - 5.0 - 9.0 * swing
	m.pixel_line(Vector2(ax + 11, ay + 3), Vector2(roundf(hx + 2), roundf(hy + 3)), Pal.L_O)
	_r(hx - 1, hy, 5, 4, Pal.U_K)
	_r(hx, hy + 1, 3, 2, Pal.L_A)
	if cyc >= 300 and cyc < 700:
		var k := float(cyc - 300) / 400.0
		for i in 6:
			var a := -PI * 0.85 + float(i) * 0.3
			_r(ax + 5.0 + cos(a) * 12.0 * k, ay - 1.0 + sin(a) * 12.0 * k + 6.0 * k * k, 1, 1, Pal.L_Y if i % 2 == 0 else Pal.L_L)

func _tailor(t: int) -> void:
	var gy := _gy()
	var y0 := gy - 60.0
	# 屋脊上的大剪刀：两片刀刃开合
	var px := 840.0
	var py := y0 + 1.0
	var open := 0.12 + 0.34 * (0.5 + 0.5 * sin(float(t) / 420.0))
	for s: float in [-1.0, 1.0]:
		var a := -PI / 2.0 + s * open
		var tip := Vector2(roundf(px + cos(a) * 22.0), roundf(py + sin(a) * 22.0))
		m.pixel_line(Vector2(px + s * 1.0, py), tip + Vector2(s, 0), Pal.U_K)
		m.pixel_line(Vector2(px, py), tip, Pal.L_A)
		var back := Vector2(roundf(px - cos(a) * 6.0), roundf(py - sin(a) * 6.0 + 4.0))
		_r(back.x - 4, back.y - 3, 8, 8, Pal.U_K)
		_r(back.x - 3, back.y - 2, 6, 6, Pal.L_R)
		_r(back.x - 1, back.y, 2, 2, Pal.U_K)
	_disc(px, py, 2.0, Pal.U_K)
	_r(px - 1, py - 1, 2, 2, Pal.L_Y)
	# 屋檐下一串彩旗，一点点晃
	var cols := [Pal.L_R, Pal.L_Y, Pal.L_B, Pal.L_G, Pal.L_P]
	var x0 := 821.0
	var x1 := 859.0
	var ey := y0 + 22.0
	m.pixel_line(Vector2(x0, ey), Vector2(x1, ey), Pal.U_K)
	var n := 9
	for i in n:
		var fx := x0 + 2.0 + float(i) * (x1 - x0 - 4.0) / float(n - 1)
		var sag := roundf(sin(float(i) / float(n - 1) * PI) * 2.0)
		var wob := roundf(sin(float(t) / 380.0 + float(i) * 0.9))
		_r(fx - 2 + wob * 0.0, ey + 1 + sag, 5, 1, cols[i % cols.size()])
		_r(fx - 1 + wob, ey + 2 + sag, 3, 1, cols[i % cols.size()])
		_r(fx + wob, ey + 3 + sag, 1, 1, cols[i % cols.size()])
	# 门上的条纹遮阳篷（下摆一圈小圆弧，轻轻起伏）
	var tx := 822.0
	var ty := y0 + 40.0
	_r(tx - 1, ty - 1, 16, 1, Pal.U_K)
	for i in 14:
		var stripe: Color = Pal.L_R if (i / 2) % 2 == 0 else Pal.L_W
		_r(tx + i, ty, 1, 4, stripe)
		var scallop := 1 if (i % 2 == 0) else 0
		var bob := roundf(sin(float(t) / 500.0 + float(i) * 0.4) * 0.6)
		_r(tx + i, ty + 4 + scallop + bob, 1, 1, stripe)

func _tackle(t: int, dark: float) -> void:
	var gy := _gy()
	var y0 := gy - 60.0
	# 屋顶上趴着一条大鱼：身子、鱼鳍、眼睛，尾巴一摆一摆，嘴里时不时吐泡泡
	var fx := 899.0
	var fy := y0 - 4.0
	_r(fx - 12, fy + 8, 3, 4, Pal.U_O)
	_r(fx + 8, fy + 8, 3, 4, Pal.U_O)
	var tw := roundf(sin(float(t) / 260.0) * 3.0)
	for i in 8:                                              # 尾巴
		var spread := float(i) * 0.75
		_r(fx - 22 + i * 0.0 + float(i) * 0.5 - float(i) * 0.5, fy - 1 - spread + tw * float(i) / 7.0, 2, 1 + roundf(spread * 2.0), Pal.U_K)
	for i in 8:
		var spread2 := float(i) * 0.75
		_r(fx - 21 + float(i) * 0.5, fy - spread2 + tw * float(i) / 7.0 + 1, 2, roundf(spread2 * 2.0), Pal.L_B)
	_ell(fx, fy + 3.0, 15.0, 8.0, Pal.U_K)
	_ell(fx, fy + 3.0, 14.0, 7.0, Pal.L_B)
	_ell(fx + 1, fy + 6.0, 12.0, 3.0, Pal.L_C)               # 肚皮
	_r(fx - 6, fy - 5, 10, 2, Pal.U_B)                       # 背鳍
	_r(fx - 4, fy - 7, 6, 2, Pal.U_B)
	for i in 4:                                              # 鳞片
		_r(fx - 8 + i * 4, fy + 1 + (i % 2) * 2, 2, 1, Pal.U_B)
	_r(fx + 8, fy, 4, 4, Pal.L_W)                            # 眼睛
	_r(fx + 10, fy + 1, 2, 2, Pal.U_K)
	_r(fx + 13, fy + 5, 3, 1, Pal.U_K)                       # 嘴
	var bp := fposmod(float(t) / 2200.0, 1.0)
	_disc(fx + 17.0 + sin(bp * 9.0) * 1.5, fy + 3.0 - bp * 22.0, 1.0 + bp * 1.5, Color(Pal.U_W, 1.0 - bp))
	# 伸出屋檐的大钓竿，线上吊着一条小鱼晃荡
	var rx0 := 874.0
	var ry0 := y0 + 24.0
	var tipx := 858.0
	var tipy := y0 + 5.0
	m.pixel_line(Vector2(rx0, ry0 + 1), Vector2(tipx, tipy + 1), Pal.U_K)
	m.pixel_line(Vector2(rx0, ry0), Vector2(tipx, tipy), Pal.L_O)
	var sway := sin(float(t) / 700.0) * 2.0
	var ly := tipy + 20.0 + sin(float(t) / 900.0) * 1.5
	m.pixel_line(Vector2(tipx, tipy), Vector2(roundf(tipx + sway), roundf(ly)), Pal.L_W)
	var sx := roundf(tipx + sway)
	_r(sx - 3, ly, 7, 4, Pal.U_K)
	_r(sx - 2, ly + 1, 5, 2, Pal.L_Y)
	_r(sx + 2, ly, 2, 4, Pal.L_Y)
	_r(sx - 4, ly + 1, 2, 2, Pal.L_Y)
	_r(sx - 1, ly + 1, 1, 1, Pal.U_K)
	# 门边挂着的灯笼：摇摆，天黑发光
	var lx := 908.0 + roundf(sin(float(t) / 900.0) * 1.5)
	var ly2 := y0 + 36.0
	_r(lx, ly2 - 8, 1, 8, Pal.U_K)
	_r(lx - 3, ly2, 7, 8, Pal.U_K)
	_r(lx - 2, ly2 + 1, 5, 6, Pal.L_R if dark < 0.35 else Pal.L_Y)
	_r(lx - 1, ly2 + 2, 3, 2, Pal.L_L)
	if dark > 0.35:
		_disc(lx + 0.5, ly2 + 4.0, 9.0, Color(Pal.L_Y, 0.16 + 0.04 * sin(float(t) / 130.0)))

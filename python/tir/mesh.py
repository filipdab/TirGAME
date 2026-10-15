"""Prosty generator siatek: prostopadłościany, walce, stożki w jednym Geomie."""
import math

from panda3d.core import (Geom, GeomNode, GeomTriangles, GeomVertexData,
                          GeomVertexFormat, GeomVertexWriter, NodePath)


class MeshBuilder:
    def __init__(self, name="mesh"):
        self.name = name
        self.vdata = GeomVertexData(name, GeomVertexFormat.get_v3n3c4(), Geom.UH_static)
        self.vw = GeomVertexWriter(self.vdata, "vertex")
        self.nw = GeomVertexWriter(self.vdata, "normal")
        self.cw = GeomVertexWriter(self.vdata, "color")
        self.tris = GeomTriangles(Geom.UH_static)
        self.tris.set_index_type(Geom.NT_uint32)
        self.count = 0

    def _vertex(self, p, n, c):
        self.vw.add_data3(*p)
        self.nw.add_data3(*n)
        self.cw.add_data4(*c)
        self.count += 1
        return self.count - 1

    def tri(self, a, b, c, normal, color):
        i = [self._vertex(p, normal, color) for p in (a, b, c)]
        self.tris.add_vertices(*i)

    def quad(self, a, b, c, d, normal, color):
        i = [self._vertex(p, normal, color) for p in (a, b, c, d)]
        self.tris.add_vertices(i[0], i[1], i[2])
        self.tris.add_vertices(i[0], i[2], i[3])

    def box(self, center, size, color, h=0.0):
        """center = środek podstawy (x, y, z), size = (dł. X, szer. Y, wys. Z), h = obrót wokół Z (radiany)."""
        cx, cy, cz = center
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2]
        ch, sh = math.cos(h), math.sin(h)

        def rot(x, y):
            return (cx + x * ch - y * sh, cy + x * sh + y * ch)

        def pt(x, y, z):
            rx, ry = rot(x, y)
            return (rx, ry, cz + z)

        def nrm(x, y, z):
            return (x * ch - y * sh, x * sh + y * ch, z)

        c = [pt(x, y, z) for z in (0, sz) for y in (-sy, sy) for x in (-sx, sx)]
        # indeksy: 0(-,-,0) 1(+,-,0) 2(-,+,0) 3(+,+,0) 4..7 to samo na górze
        self.quad(c[4], c[5], c[7], c[6], (0, 0, 1), color)          # góra
        self.quad(c[0], c[2], c[3], c[1], (0, 0, -1), color)         # dół
        self.quad(c[1], c[3], c[7], c[5], nrm(1, 0, 0), color)       # +X
        self.quad(c[0], c[4], c[6], c[2], nrm(-1, 0, 0), color)      # -X
        self.quad(c[2], c[6], c[7], c[3], nrm(0, 1, 0), color)       # +Y
        self.quad(c[0], c[1], c[5], c[4], nrm(0, -1, 0), color)      # -Y

    def cylinder(self, base, radius, height, color, segments=16, top_radius=None):
        """Walec (albo stożek, gdy top_radius=0) o osi Z, base = środek podstawy."""
        bx, by, bz = base
        tr = radius if top_radius is None else top_radius
        ring = [(math.cos(2 * math.pi * i / segments), math.sin(2 * math.pi * i / segments))
                for i in range(segments + 1)]
        top = (bx, by, bz + height)
        slope = (radius - tr) / height if height else 0
        for i in range(segments):
            (c0, s0), (c1, s1) = ring[i], ring[i + 1]
            cm, sm = (c0 + c1) / 2, (s0 + s1) / 2
            n = (cm, sm, slope)
            a = (bx + c0 * radius, by + s0 * radius, bz)
            b = (bx + c1 * radius, by + s1 * radius, bz)
            if tr > 0:
                c = (bx + c1 * tr, by + s1 * tr, bz + height)
                d = (bx + c0 * tr, by + s0 * tr, bz + height)
                self.quad(a, b, c, d, n, color)
                self.tri(top, d, c, (0, 0, 1), color)
            else:
                self.tri(a, b, top, n, color)

    def node(self):
        geom = Geom(self.vdata)
        geom.add_primitive(self.tris)
        gn = GeomNode(self.name)
        gn.add_geom(geom)
        np = NodePath(gn)
        np.set_two_sided(True)
        return np

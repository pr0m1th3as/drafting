/*
Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>

This file is part of the drafting package for GNU Octave.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, see <http://www.gnu.org/licenses/>.
*/

#include <algorithm>
#include <array>
#include <cmath>
#include <functional>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include <octave/oct.h>

#include <APIHeaderSection_MakeHeader.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_BooleanOperation.hxx>
#include <TopLoc_Location.hxx>
#include <TDF_Tool.hxx>
#include <BRepBuilderAPI_MakeShape.hxx>
#include <TopTools_DataMapOfShapeInteger.hxx>
#include <Quantity_Color.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFApp_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDataStd_Name.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepIntCurveSurface_Inter.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <IntTools_Context.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRep_Builder.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepTools.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRepTools_ReShape.hxx>
#include <BRepLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffset_MakeOffset.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepPrimAPI_MakeWedge.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRep_Tool.hxx>
#include <BinTools.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Approx_ParametrizationType.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <GCE2d_MakeArcOfCircle.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GeomAPI.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <Bnd_Box2d.hxx>
#include <IntRes2d_IntersectionSegment.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Pln.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <GProp_GProps.hxx>
#include <Interface_Static.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <Poly_Triangulation.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <Standard_Failure.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Mat.hxx>
#include <gp_Trsf.hxx>

using namespace std;

// Every shape crosses into Octave as the bytes of OCCT's binary format, which
// begin with this signature.  Bytes without it never reach the reader.
static const char signature[] = "\nOpen CASCADE Topology V";

// OCCT prints progress to stdout through its default messenger.  A library
// call has no business writing to the command window, so the printers are
// removed once, before the first call that could use them.
static void
quiet ()
{
  static bool done = false;
  if (! done)
  {
    Message::DefaultMessenger ()->ChangePrinters ().Clear ();
    done = true;
  }
}

// The number of distinct sub-shapes of one kind.  A shared edge is counted
// once, which a plain explorer does not do.
static octave_idx_type
count (const TopoDS_Shape& s, TopAbs_ShapeEnum type)
{
  if (s.IsNull ())
  {
    return 0;
  }
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, type, map);
  return map.Extent ();
}

// A shape from the bytes held by a solid.Shape; empty bytes are the empty
// shape.
static TopoDS_Shape
toshape (const octave_value& v, const string& caller)
{
  TopoDS_Shape s;
  if (v.isempty ())
  {
    return s;
  }
  if (! v.is_uint8_type ())
  {
    error ("%s: shape data must be uint8.", caller.c_str ());
  }
  const uint8NDArray a = v.uint8_array_value ();
  const size_t n = a.numel ();
  const size_t m = sizeof (signature) - 1;
  string bytes (n, '\0');
  for (size_t i = 0; i < n; i++)
  {
    bytes[i] = static_cast<char> (a(i).value ());
  }
  if (n < m || bytes.compare (0, m, signature) != 0)
  {
    error ("%s: shape data is not an Open CASCADE shape.", caller.c_str ());
  }
  istringstream is (bytes);
  BinTools::Read (s, is);
  return s;
}

// The bytes of a shape.  A shape with no faces, such as the result of
// intersecting two solids that do not meet, is returned as the empty shape.
static octave_value
todata (const TopoDS_Shape& s)
{
  if (count (s, TopAbs_FACE) == 0)
  {
    return octave_value (uint8NDArray (dim_vector (0, 0)));
  }
  ostringstream os;
  BinTools::Write (s, os, Standard_False, Standard_False,
                   BinTools_FormatVersion_CURRENT);
  const string bytes = os.str ();
  uint8NDArray a (dim_vector (1, bytes.size ()));
  for (size_t i = 0; i < bytes.size (); i++)
  {
    a(i) = static_cast<unsigned char> (bytes[i]);
  }
  return octave_value (a);
}

static gp_Pnt
topoint (const octave_value& v)
{
  const NDArray a = v.array_value ();
  return gp_Pnt (a(0), a(1), a(2));
}

static gp_Dir
todir (const octave_value& v)
{
  const NDArray a = v.array_value ();
  return gp_Dir (a(0), a(1), a(2));
}

// The B-spline of a geom.Spline as solid.__path__ hands it over: its control
// points, their weights, its distinct knots and their multiplicities, and
// its degree; rational when the weights differ
static Handle (Geom_BSplineCurve)
bspline (const octave_scalar_map& s)
{
  const Matrix p = s.contents ("poles").matrix_value ();
  const ColumnVector w = s.contents ("weights").column_vector_value ();
  const ColumnVector t = s.contents ("knots").column_vector_value ();
  const ColumnVector m = s.contents ("mults").column_vector_value ();
  const int degree = s.contents ("degree").int_value ();
  TColgp_Array1OfPnt poles (1, p.rows ());
  TColStd_Array1OfReal weights (1, p.rows ());
  for (octave_idx_type i = 0; i < p.rows (); i++)
  {
    poles.SetValue (i + 1, gp_Pnt (p(i,0), p(i,1), p(i,2)));
    weights.SetValue (i + 1, w(i));
  }
  TColStd_Array1OfReal knots (1, t.numel ());
  TColStd_Array1OfInteger mults (1, t.numel ());
  for (octave_idx_type i = 0; i < t.numel (); i++)
  {
    knots.SetValue (i + 1, t(i));
    mults.SetValue (i + 1, static_cast<int> (m(i)));
  }
  return new Geom_BSplineCurve (poles, weights, knots, mults, degree);
}

// The wire of a geom.Path as solid.__path__ hands it over, in world
// coordinates: its vertices; the midpoints of its arcs, NaN for a segment
// that is not an arc; for each spline segment the control points of its cubic
// pieces and the parameters where they meet; and whether it is closed, its
// last segment then running back to the first vertex, or for a path of one
// vertex its one spline running round to it
static TopoDS_Wire
chain (const octave_value& p)
{
  const octave_scalar_map s = p.scalar_map_value ();
  const Matrix v = s.contents ("vertices").matrix_value ();
  const Matrix m = s.contents ("midpoints").matrix_value ();
  const Cell sp = s.contents ("splines").cell_value ();
  const bool closed = s.contents ("closed").bool_value ();
  const octave_idx_type n = v.rows ();
  BRepBuilderAPI_MakeWire w;
  for (octave_idx_type i = 0; i < (closed ? n : n - 1); i++)
  {
    const octave_idx_type j = (i + 1) % n;
    const gp_Pnt a (v(i,0), v(i,1), v(i,2));
    const gp_Pnt b (v(j,0), v(j,1), v(j,2));
    if (! sp(i).isempty ())
    {
      w.Add (BRepBuilderAPI_MakeEdge (bspline (sp(i).scalar_map_value ()))
             .Edge ());
    }
    else if (octave::math::isnan (m(i,0)))
    {
      w.Add (BRepBuilderAPI_MakeEdge (a, b).Edge ());
    }
    else
    {
      const Handle (Geom_TrimmedCurve) arc
        = GC_MakeArcOfCircle (a, gp_Pnt (m(i,0), m(i,1), m(i,2)), b)
          .Value ();
      w.Add (BRepBuilderAPI_MakeEdge (arc).Edge ());
    }
  }
  return w.Wire ();
}

// A geom.Region as Octave hands it over: the outline and a cell of the
// holes, each a path as chain reads it, and the frame of its plane, rows
// origin, x axis, y axis and normal.  The outline runs anticlockwise and the
// holes clockwise.
struct region
{
  TopoDS_Wire outer;
  vector<TopoDS_Wire> holes;
  gp_Pnt origin;
  gp_Dir x, y, normal;
};

static region
toregion (const octave_value& v)
{
  const octave_scalar_map m = v.scalar_map_value ();
  const Matrix f = m.contents ("frame").matrix_value ();
  const gp_XYZ o (f(0,0), f(0,1), f(0,2));
  const gp_XYZ u (f(1,0), f(1,1), f(1,2));
  const gp_XYZ w (f(2,0), f(2,1), f(2,2));
  region r;
  r.origin = gp_Pnt (o);
  r.x = gp_Dir (u);
  r.y = gp_Dir (w);
  r.normal = gp_Dir (f(3,0), f(3,1), f(3,2));
  r.outer = chain (m.contents ("outline"));
  const Cell h = m.contents ("holes").cell_value ();
  for (octave_idx_type i = 0; i < h.numel (); i++)
  {
    r.holes.push_back (chain (h(i)));
  }
  return r;
}

// The planar face a region bounds, its holes as inner wires
static TopoDS_Face
planarface (const region& r)
{
  BRepBuilderAPI_MakeFace f (r.outer, Standard_True);
  for (const TopoDS_Wire& h : r.holes)
  {
    f.Add (h);
  }
  return f.Face ();
}

// One piece of a closed loop lying in a plane: a straight segment, an arc or
// one span of a spline between two knots, as a curve in the coordinates of
// the plane, with the loop it belongs to and its place there, its ends, its
// box and the edge it makes in the xy plane
struct piece
{
  Handle (Geom2d_Curve) curve;
  int loop, index;
  bool spline;
  gp_Pnt2d a, b;
  double x0, y0, x1, y1;
  TopoDS_Edge edge;
};

// Row I of the points P, in world coordinates, in the plane of the frame F,
// rows origin, x axis, y axis and normal
static gp_Pnt2d
inplane (const Matrix& p, octave_idx_type i, const Matrix& f)
{
  const double d[3] = {p(i,0) - f(0,0), p(i,1) - f(0,1), p(i,2) - f(0,2)};
  return gp_Pnt2d (d[0] * f(1,0) + d[1] * f(1,1) + d[2] * f(1,2),
                   d[0] * f(2,0) + d[1] * f(2,1) + d[2] * f(2,2));
}

// The pieces of the closed path P, as chain reads it, in the plane of the
// frame F, appended to OUT as loop LOOP; returns how many there are
static int
pieces (const octave_value& p, const Matrix& f, int loop, vector<piece>& out)
{
  const octave_scalar_map s = p.scalar_map_value ();
  const Matrix v = s.contents ("vertices").matrix_value ();
  const Matrix m = s.contents ("midpoints").matrix_value ();
  const Cell sp = s.contents ("splines").cell_value ();
  const octave_idx_type n = v.rows ();
  int count = 0;
  for (octave_idx_type i = 0; i < n; i++)
  {
    const gp_Pnt2d a = inplane (v, i, f);
    const gp_Pnt2d b = inplane (v, (i + 1) % n, f);
    vector<Handle (Geom2d_Curve)> c;
    if (! sp(i).isempty ())
    {
      const octave_scalar_map q = sp(i).scalar_map_value ();
      const Matrix pl = q.contents ("poles").matrix_value ();
      const ColumnVector w = q.contents ("weights").column_vector_value ();
      const ColumnVector t = q.contents ("knots").column_vector_value ();
      const ColumnVector mu = q.contents ("mults").column_vector_value ();
      TColgp_Array1OfPnt2d poles (1, pl.rows ());
      TColStd_Array1OfReal weights (1, pl.rows ());
      for (octave_idx_type k = 0; k < pl.rows (); k++)
      {
        poles.SetValue (k + 1, inplane (pl, k, f));
        weights.SetValue (k + 1, w(k));
      }
      TColStd_Array1OfReal knots (1, t.numel ());
      TColStd_Array1OfInteger mults (1, t.numel ());
      for (octave_idx_type k = 0; k < t.numel (); k++)
      {
        knots.SetValue (k + 1, t(k));
        mults.SetValue (k + 1, static_cast<int> (mu(k)));
      }
      const Handle (Geom2d_BSplineCurve) whole
        = new Geom2d_BSplineCurve (poles, weights, knots, mults,
                                   q.contents ("degree").int_value ());
      for (int k = whole->FirstUKnotIndex (); k < whole->LastUKnotIndex ();
           k++)
      {
        Handle (Geom2d_BSplineCurve) span
          = Handle (Geom2d_BSplineCurve)::DownCast (whole->Copy ());
        span->Segment (whole->Knot (k), whole->Knot (k + 1));
        c.push_back (span);
      }
    }
    else if (octave::math::isnan (m(i,0)))
    {
      c.push_back (GCE2d_MakeSegment (a, b).Value ());
    }
    else
    {
      c.push_back (GCE2d_MakeArcOfCircle (a, inplane (m, i, f), b).Value ());
    }
    for (const Handle (Geom2d_Curve)& k : c)
    {
      piece q;
      q.curve = k;
      q.loop = loop;
      q.index = count++;
      q.spline = ! sp(i).isempty ();
      q.a = k->Value (k->FirstParameter ());
      q.b = k->Value (k->LastParameter ());
      Bnd_Box2d box;
      BndLib_Add2dCurve::AddOptimal (k, k->FirstParameter (),
                                     k->LastParameter (),
                                     Precision::Confusion (), box);
      box.Get (q.x0, q.y0, q.x1, q.y1);
      q.edge = BRepBuilderAPI_MakeEdge (GeomAPI::To3d (k, gp_Pln (gp::XOY ())))
                 .Edge ();
      out.push_back (q);
    }
  }
  return count;
}

// Whether the pieces P and Q, next to one another in a loop, meet anywhere
// but at the ends they share, within Open CASCADE's tolerance
static bool
meetapart (const piece& p, const piece& q)
{
  const double tol = Precision::Confusion ();
  vector<gp_Pnt2d> shared;
  for (const gp_Pnt2d& s : {p.a, p.b})
  {
    for (const gp_Pnt2d& t : {q.a, q.b})
    {
      if (s.Distance (t) <= tol)
      {
        shared.push_back (s);
      }
    }
  }
  // The shared end a point lies at, or -1
  auto atshared = [&shared, tol] (const gp_Pnt2d& z)
  {
    for (size_t i = 0; i < shared.size (); i++)
    {
      if (z.Distance (shared[i]) <= tol)
      {
        return static_cast<int> (i);
      }
    }
    return -1;
  };
  Geom2dAPI_InterCurveCurve x (p.curve, q.curve, tol);
  for (int i = 1; i <= x.NbPoints (); i++)
  {
    if (atshared (x.Point (i)) < 0)
    {
      return true;
    }
  }
  // A run along which the two lie together is allowed only as a point at a
  // shared end; it is read from the intersector, since a run of no length
  // cannot be made a curve
  for (int i = 1; i <= x.NbSegments (); i++)
  {
    const IntRes2d_IntersectionSegment& g = x.Intersector ().Segment (i);
    if (! g.HasFirstPoint () || ! g.HasLastPoint ())
    {
      return true;
    }
    const int e = atshared (g.FirstPoint ().Value ());
    if (e < 0 || e != atshared (g.LastPoint ().Value ()))
    {
      return true;
    }
  }
  return false;
}

// Which of the closed loops L, paths as chain reads them lying in the plane
// of the frame F, cross or touch themselves, which cross or touch one
// another, and which lie inside which: a struct of CROSS, a logical row, and
// MEET and INSIDE, logical matrices, INSIDE(J,K) true when loop J lies inside
// loop K.  Each is judged on the exact curves, a spline span by span, two
// curves meeting where they come within Open CASCADE's tolerance; pieces are
// paired only where their boxes overlap.  INSIDE is found only when no loop
// crosses itself, and only for loops that do not meet.
static octave_value
loopcheck (const Cell& L, const Matrix& f)
{
  const double tol = Precision::Confusion ();
  const int n = L.numel ();
  vector<piece> P;
  vector<int> count (n);
  for (int k = 0; k < n; k++)
  {
    count[k] = pieces (L(k), f, k, P);
  }
  boolMatrix cross (1, n, false);
  boolMatrix meet (n, n, false);
  boolMatrix inside (n, n, false);

  // A span of a spline may loop on itself
  for (const piece& p : P)
  {
    if (p.spline && ! cross(p.loop))
    {
      Geom2dAPI_InterCurveCurve x (p.curve, tol);
      cross(p.loop) = x.NbPoints () > 0 || x.NbSegments () > 0;
    }
  }

  // The pairs whose boxes overlap, swept along x
  vector<size_t> o (P.size ());
  for (size_t i = 0; i < o.size (); i++)
  {
    o[i] = i;
  }
  sort (o.begin (), o.end (),
        [&P] (size_t i, size_t j) { return P[i].x0 < P[j].x0; });
  for (size_t i = 0; i < o.size (); i++)
  {
    const piece& p = P[o[i]];
    for (size_t j = i + 1; j < o.size () && P[o[j]].x0 <= p.x1; j++)
    {
      const piece& q = P[o[j]];
      if (q.y0 > p.y1 || q.y1 < p.y0)
      {
        continue;
      }
      if (p.loop == q.loop)
      {
        const int d = abs (p.index - q.index);
        if (cross(p.loop))
        {
          continue;
        }
        else if (d == 1 || d == count[p.loop] - 1)
        {
          cross(p.loop) = meetapart (p, q);
        }
        else
        {
          BRepExtrema_DistShapeShape x (p.edge, q.edge);
          cross(p.loop) = x.IsDone () && x.Value () <= tol;
        }
      }
      else if (! meet(p.loop, q.loop))
      {
        BRepExtrema_DistShapeShape x (p.edge, q.edge);
        meet(p.loop, q.loop) = x.IsDone () && x.Value () <= tol;
        meet(q.loop, p.loop) = meet(p.loop, q.loop);
      }
    }
  }

  // A loop lies inside another, which it does not meet, when its first point
  // does and its box lies within the other's
  bool any = false;
  for (int k = 0; k < n; k++)
  {
    any = any || cross(k);
  }
  if (! any && n > 1)
  {
    vector<TopoDS_Face> face (n);
    vector<Bnd_Box2d> box (n);
    vector<gp_Pnt2d> first (n);
    vector<BRepBuilderAPI_MakeWire> wire (n);
    for (const piece& p : P)
    {
      if (p.index == 0)
      {
        first[p.loop] = p.a;
      }
      wire[p.loop].Add (p.edge);
      box[p.loop].Update (p.x0, p.y0, p.x1, p.y1);
    }
    for (int k = 0; k < n; k++)
    {
      face[k] = BRepBuilderAPI_MakeFace (gp_Pln (gp::XOY ()), wire[k].Wire (),
                                         Standard_True).Face ();
    }
    for (int j = 0; j < n; j++)
    {
      double a0, b0, a1, b1, c0, d0, c1, d1;
      box[j].Get (a0, b0, a1, b1);
      for (int k = 0; k < n; k++)
      {
        box[k].Get (c0, d0, c1, d1);
        if (j != k && ! meet(j,k)
            && a0 >= c0 && b0 >= d0 && a1 <= c1 && b1 <= d1)
        {
          BRepClass_FaceClassifier c (face[k],
                                      gp_Pnt (first[j].X (), first[j].Y (),
                                              0),
                                      tol);
          inside(j,k) = c.State () == TopAbs_IN;
        }
      }
    }
  }

  octave_scalar_map r;
  r.assign ("cross", cross);
  r.assign ("meet", meet);
  r.assign ("inside", inside);
  return octave_value (r);
}

// One side of an extrusion of R, height H along its normal, its walls leaning
// in by A radians (out when A is negative), corners kept sharp as a drafted
// wall's are: each outline is joined by straight lines to its offset at the
// top, and the holes are cut from the outline.
static TopoDS_Shape
taperedside (const region& r, double h, double a, const string& caller);

// S less every shape in TOOLS, in one operation
static TopoDS_Shape
cutall (const TopoDS_Shape& s, const vector<TopoDS_Shape>& tools,
        const string& caller);

// The sub-shapes of one kind picked by 1-based indices into the map of all of
// them, which is the order in which the queries report them.  The indices have
// been checked against the count by the caller.
static TopTools_ListOfShape
picked (const TopoDS_Shape& s, TopAbs_ShapeEnum type, const NDArray& idx)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, type, map);
  TopTools_ListOfShape list;
  for (octave_idx_type i = 0; i < idx.numel (); i++)
  {
    list.Append (map (static_cast<int> (idx(i))));
  }
  return list;
}

// The bounding box of a sub-shape as a row of a matrix
static void
boxrow (const TopoDS_Shape& s, Matrix& m, octave_idx_type i)
{
  Bnd_Box b;
  BRepBndLib::AddOptimal (s, b, Standard_False, Standard_False);
  double x0, y0, z0, x1, y1, z1;
  b.Get (x0, y0, z0, x1, y1, z1);
  m(i,0) = x0;
  m(i,1) = y0;
  m(i,2) = z0;
  m(i,3) = x1;
  m(i,4) = y1;
  m(i,5) = z1;
}

static void
dirrow (const gp_Dir& d, Matrix& m, octave_idx_type i)
{
  m(i,0) = d.X ();
  m(i,1) = d.Y ();
  m(i,2) = d.Z ();
}

// The edges of a shape: the kind of curve each lies on, its direction (a
// line's, or the axis of a circle or ellipse), its bounding box, whether it is
// a seam or a degenerate edge, which bounds a face without being a feature of
// the part, and the indices of the faces it bounds.
static Cell
edgeinfo (const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, TopAbs_EDGE, map);
  TopTools_IndexedDataMapOfShapeListOfShape faces;
  TopExp::MapShapesAndAncestors (s, TopAbs_EDGE, TopAbs_FACE, faces);
  TopTools_IndexedMapOfShape fmap;
  TopExp::MapShapes (s, TopAbs_FACE, fmap);
  const octave_idx_type n = map.Extent ();
  Cell type (n, 1);
  Cell onfaces (n, 1);
  Matrix dir (n, 3, octave_NaN);
  Matrix box (n, 6);
  boolNDArray seam (dim_vector (n, 1), false);
  for (octave_idx_type i = 0; i < n; i++)
  {
    const TopoDS_Edge e = TopoDS::Edge (map (i + 1));
    boxrow (e, box, i);
    if (BRep_Tool::Degenerated (e))
    {
      type(i) = "degenerate";
      seam(i) = true;
      onfaces(i) = RowVector (0);
      continue;
    }
    const BRepAdaptor_Curve c (e);
    switch (c.GetType ())
    {
      case GeomAbs_Line:
        type(i) = "line";
        dirrow (c.Line ().Direction (), dir, i);
        break;
      case GeomAbs_Circle:
        type(i) = "circle";
        dirrow (c.Circle ().Axis ().Direction (), dir, i);
        break;
      case GeomAbs_Ellipse:
        type(i) = "ellipse";
        dirrow (c.Ellipse ().Axis ().Direction (), dir, i);
        break;
      case GeomAbs_BSplineCurve:
      case GeomAbs_BezierCurve:
        type(i) = "bspline";
        break;
      default:
        type(i) = "other";
    }
    const int k = faces.FindIndex (e);
    if (k > 0)
    {
      RowVector idx (0);
      for (const TopoDS_Shape& f : faces (k))
      {
        if (BRep_Tool::IsClosed (e, TopoDS::Face (f)))
        {
          seam(i) = true;
        }
        const int j = fmap.FindIndex (f);
        bool seen = false;
        for (octave_idx_type q = 0; q < idx.numel (); q++)
        {
          seen = seen || idx(q) == j;
        }
        if (! seen)
        {
          idx.resize (idx.numel () + 1, j);
        }
      }
      onfaces(i) = idx;
    }
    else
    {
      onfaces(i) = RowVector (0);
    }
  }
  return Cell (ovl (type, dir, box, seam, onfaces));
}

// The faces of a shape: the kind of surface each lies on, the outward normal
// of a plane, the axis of a surface of revolution, and its bounding box
static Cell
faceinfo (const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, TopAbs_FACE, map);
  const octave_idx_type n = map.Extent ();
  Cell type (n, 1);
  Matrix normal (n, 3, octave_NaN);
  Matrix axis (n, 3, octave_NaN);
  Matrix box (n, 6);
  for (octave_idx_type i = 0; i < n; i++)
  {
    const TopoDS_Face f = TopoDS::Face (map (i + 1));
    boxrow (f, box, i);
    const BRepAdaptor_Surface a (f);
    switch (a.GetType ())
    {
      case GeomAbs_Plane:
      {
        type(i) = "plane";
        gp_Dir d = a.Plane ().Axis ().Direction ();
        if (f.Orientation () == TopAbs_REVERSED)
        {
          d.Reverse ();
        }
        dirrow (d, normal, i);
        break;
      }
      case GeomAbs_Cylinder:
        type(i) = "cylinder";
        dirrow (a.Cylinder ().Axis ().Direction (), axis, i);
        break;
      case GeomAbs_Cone:
        type(i) = "cone";
        dirrow (a.Cone ().Axis ().Direction (), axis, i);
        break;
      case GeomAbs_Sphere:
        type(i) = "sphere";
        break;
      case GeomAbs_Torus:
        type(i) = "torus";
        dirrow (a.Torus ().Axis ().Direction (), axis, i);
        break;
      case GeomAbs_SurfaceOfRevolution:
        type(i) = "revolution";
        dirrow (a.AxeOfRevolution ().Direction (), axis, i);
        break;
      case GeomAbs_SurfaceOfExtrusion:
        type(i) = "extrusion";
        break;
      case GeomAbs_BSplineSurface:
      case GeomAbs_BezierSurface:
        type(i) = "bspline";
        break;
      default:
        type(i) = "other";
    }
  }
  return Cell (ovl (type, normal, axis, box));
}

// The volume and centre of volume of S, integrated adaptively to a relative
// error of 1e-9 on every face.  The default integration, of fixed order, errs
// by up to a part in a thousand on spline faces.  The adaptive one computes
// the centre only when asked to.  Should it fail, the default is taken.
static GProp_GProps
volumeprops (const TopoDS_Shape& s)
{
  GProp_GProps p;
  if (BRepGProp::VolumePropertiesGK (s, p, 1e-9, Standard_False,
                                     Standard_True, Standard_True) < 0)
  {
    p = GProp_GProps ();
    BRepGProp::VolumeProperties (s, p);
  }
  return p;
}

// The area of S, face by face.  A planar face's area is the volume of the
// prism of unit height on it, which the adaptive volume integration finds
// exactly however its edges curve; a curved face takes Open CASCADE's surface
// integration, the only one it has.
static double
area (const TopoDS_Shape& s)
{
  double a = 0;
  for (TopExp_Explorer x (s, TopAbs_FACE); x.More (); x.Next ())
  {
    const TopoDS_Face f = TopoDS::Face (x.Current ());
    const BRepAdaptor_Surface g (f, Standard_False);
    if (g.GetType () == GeomAbs_Plane)
    {
      BRepPrimAPI_MakePrism prism (f, gp_Vec (g.Plane ().Axis ().Direction ()));
      if (prism.IsDone ())
      {
        GProp_GProps p;
        if (BRepGProp::VolumePropertiesGK (prism.Shape (), p, 1e-9) >= 0)
        {
          a += std::abs (p.Mass ());
          continue;
        }
      }
    }
    GProp_GProps p;
    BRepGProp::SurfaceProperties (f, p);
    a += p.Mass ();
  }
  return a;
}

// A point with z = 0, for a section cut in the plane z = 0
static RowVector
flat (const gp_Pnt& p)
{
  RowVector r (3);
  r(0) = p.X ();
  r(1) = p.Y ();
  r(2) = 0;
  return r;
}

// One piece of a section loop as Octave builds a path from it: a line from
// its first point to its last; an arc through its first, middle and last
// point; or a B-spline by its control points, weights, distinct knots and
// their multiplicities and degree
static octave_scalar_map
sectionpiece (const char *type, const Matrix& points)
{
  octave_scalar_map m;
  m.assign ("type", type);
  m.assign ("points", points);
  return m;
}

// The edge E of a section loop, run the way the loop runs, as pieces: a line
// stays a line and a circle an arc, a whole circle two half arcs; any other
// curve is a B-spline, exact for a conic, its ends set on the edge's vertices
static void
sectionedge (const TopoDS_Edge& e, vector<octave_value>& out)
{
  const gp_Pnt p0 = BRep_Tool::Pnt (TopExp::FirstVertex (e, Standard_True));
  const gp_Pnt p1 = BRep_Tool::Pnt (TopExp::LastVertex (e, Standard_True));
  double a, b;
  const Handle (Geom_Curve) c = BRep_Tool::Curve (e, a, b);
  const bool rev = (e.Orientation () == TopAbs_REVERSED);
  const double s0 = rev ? b : a;
  const double s1 = rev ? a : b;
  const BRepAdaptor_Curve g (e);
  if (g.GetType () == GeomAbs_Line)
  {
    Matrix m (2, 3);
    m.insert (flat (p0), 0, 0);
    m.insert (flat (p1), 1, 0);
    out.push_back (sectionpiece ("line", m));
  }
  else if (g.GetType () == GeomAbs_Circle)
  {
    if (p0.Distance (p1) < Precision::Confusion ())
    {
      const gp_Pnt h = c->Value ((s0 + s1) / 2);
      Matrix m (3, 3);
      m.insert (flat (p0), 0, 0);
      m.insert (flat (c->Value (s0 + (s1 - s0) / 4)), 1, 0);
      m.insert (flat (h), 2, 0);
      out.push_back (sectionpiece ("arc", m));
      m.insert (flat (h), 0, 0);
      m.insert (flat (c->Value (s0 + 3 * (s1 - s0) / 4)), 1, 0);
      m.insert (flat (p0), 2, 0);
      out.push_back (sectionpiece ("arc", m));
    }
    else
    {
      Matrix m (3, 3);
      m.insert (flat (p0), 0, 0);
      m.insert (flat (c->Value ((s0 + s1) / 2)), 1, 0);
      m.insert (flat (p1), 2, 0);
      out.push_back (sectionpiece ("arc", m));
    }
  }
  else
  {
    const Handle (Geom_TrimmedCurve) t = new Geom_TrimmedCurve (c, a, b);
    Handle (Geom_BSplineCurve) bs;
    try
    {
      bs = GeomConvert::CurveToBSplineCurve (t);
    }
    catch (const Standard_Failure&)
    {
      bs = GeomConvert_ApproxCurve (t, 1e-7, GeomAbs_C2, 100, 12).Curve ();
    }
    if (bs->IsPeriodic ())
    {
      bs->SetNotPeriodic ();
    }
    if (rev)
    {
      bs->Reverse ();
    }
    const int n = bs->NbPoles ();
    if (bs->Degree () == 1)
    {
      // A polyline made a spline is lines from pole to pole
      bool even = true;
      for (int i = 2; i <= n && even; i++)
      {
        even = (bs->Weight (i) == bs->Weight (1));
      }
      if (even)
      {
        gp_Pnt a = p0;
        for (int i = 2; i <= n; i++)
        {
          const gp_Pnt b = (i == n) ? p1 : bs->Pole (i);
          if (a.Distance (b) > Precision::Confusion ())
          {
            Matrix m (2, 3);
            m.insert (flat (a), 0, 0);
            m.insert (flat (b), 1, 0);
            out.push_back (sectionpiece ("line", m));
            a = b;
          }
        }
        return;
      }
    }
    bs->SetPole (1, p0);
    bs->SetPole (n, p1);
    Matrix poles (n, 3);
    ColumnVector w (n);
    for (int i = 1; i <= n; i++)
    {
      poles.insert (flat (bs->Pole (i)), i - 1, 0);
      w(i-1) = bs->Weight (i);
    }
    ColumnVector k (bs->NbKnots ());
    ColumnVector m (bs->NbKnots ());
    for (int i = 1; i <= bs->NbKnots (); i++)
    {
      k(i-1) = bs->Knot (i);
      m(i-1) = bs->Multiplicity (i);
    }
    octave_scalar_map piece = sectionpiece ("spline", poles);
    piece.assign ("weights", w);
    piece.assign ("knots", k);
    piece.assign ("mults", m);
    piece.assign ("degree", bs->Degree ());
    out.push_back (piece);
  }
}

// The loop W of the face F as a cell of pieces, in the order and the sense
// the face runs it
static Cell
sectionloop (const TopoDS_Wire& w, const TopoDS_Face& f)
{
  vector<octave_value> pieces;
  for (BRepTools_WireExplorer x (w, f); x.More (); x.Next ())
  {
    sectionedge (x.Current (), pieces);
  }
  Cell c (1, pieces.size ());
  for (size_t i = 0; i < pieces.size (); i++)
  {
    c(i) = pieces[i];
  }
  return c;
}


// A closed triangle mesh as a solid: the vertices V, N-by-3, and the
// triangles F, K-by-3 indices from 1, built from the mesh's own topology, a
// vertex for each vertex, an edge for each edge two triangles share and a
// flat face for each triangle.  Every edge must belong to two triangles.
// Triangles turned the wrong way are turned to agree with their neighbours;
// each closed piece is a solid, and a piece inside another, running the
// other way, is a void in it; pieces that overlap are united.  With MERGE,
// coplanar faces that meet become one.
static TopoDS_Shape
polyhedron (const Matrix& V, const Matrix& F, bool merge, const string& caller)
{
  const octave_idx_type nv = V.rows ();
  vector<array<octave_idx_type, 3>> T;
  for (octave_idx_type t = 0; t < F.rows (); t++)
  {
    array<octave_idx_type, 3> f = {static_cast<octave_idx_type> (F(t,0)) - 1,
                                   static_cast<octave_idx_type> (F(t,1)) - 1,
                                   static_cast<octave_idx_type> (F(t,2)) - 1};
    const gp_Pnt a (V(f[0],0), V(f[0],1), V(f[0],2));
    const gp_Pnt b (V(f[1],0), V(f[1],1), V(f[1],2));
    const gp_Pnt c (V(f[2],0), V(f[2],1), V(f[2],2));
    if (f[0] != f[1] && f[1] != f[2] && f[2] != f[0]
        && gp_Vec (a, b).Crossed (gp_Vec (a, c)).Magnitude () > 0)
    {
      T.push_back (f);
    }
  }
  const size_t nt = T.size ();
  if (nt == 0)
  {
    error ("%s: the mesh has no triangles.", caller.c_str ());
  }

  // The triangles at each edge
  auto key = [nv] (octave_idx_type a, octave_idx_type b)
  {
    return static_cast<int64_t> (std::min (a, b)) * nv + std::max (a, b);
  };
  unordered_map<int64_t, vector<size_t>> at;
  at.reserve (2 * nt);
  for (size_t t = 0; t < nt; t++)
  {
    for (int e = 0; e < 3; e++)
    {
      at[key (T[t][e], T[t][(e + 1) % 3])].push_back (t);
    }
  }
  size_t open = 0, crowded = 0;
  for (const auto& p : at)
  {
    open += (p.second.size () == 1);
    crowded += (p.second.size () > 2);
  }
  if (open > 0)
  {
    error ("%s: the mesh is not closed: %zu %s to one triangle only.",
           caller.c_str (), open, open == 1 ? "edge belongs" : "edges belong");
  }
  if (crowded > 0)
  {
    error ("%s: the mesh is not manifold: %zu %s to more than two triangles.",
           caller.c_str (), crowded,
           crowded == 1 ? "edge belongs" : "edges belong");
  }

  // Each piece turned one way, from a triangle of it outwards: a neighbour
  // runs their shared edge the other way, or is turned over
  auto runs = [&] (size_t t, octave_idx_type a, octave_idx_type b)
  {
    for (int e = 0; e < 3; e++)
    {
      if (T[t][e] == a && T[t][(e + 1) % 3] == b)
      {
        return true;
      }
    }
    return false;
  };
  vector<int> piece (nt, -1);
  int np = 0;
  for (size_t s = 0; s < nt; s++)
  {
    if (piece[s] >= 0)
    {
      continue;
    }
    vector<size_t> stack = {s};
    piece[s] = np;
    while (! stack.empty ())
    {
      const size_t t = stack.back ();
      stack.pop_back ();
      for (int e = 0; e < 3; e++)
      {
        const octave_idx_type a = T[t][e], b = T[t][(e + 1) % 3];
        for (size_t u : at[key (a, b)])
        {
          if (u == t)
          {
            continue;
          }
          if (piece[u] < 0)
          {
            if (runs (u, a, b))
            {
              std::swap (T[u][1], T[u][2]);
            }
            piece[u] = np;
            stack.push_back (u);
          }
          else if (piece[u] == np && runs (u, a, b))
          {
            error ("%s: the mesh is one-sided, as a Klein bottle, and"
                   " encloses no volume.", caller.c_str ());
          }
        }
      }
    }
    np++;
  }

  // The vertices and edges, shared, and each piece's shell of flat faces
  BRep_Builder bb;
  vector<TopoDS_Vertex> vx (nv);
  auto vertex = [&] (octave_idx_type i)
  {
    if (vx[i].IsNull ())
    {
      bb.MakeVertex (vx[i], gp_Pnt (V(i,0), V(i,1), V(i,2)),
                     Precision::Confusion ());
    }
    return vx[i];
  };
  unordered_map<int64_t, TopoDS_Edge> ed;
  ed.reserve (2 * nt);
  vector<TopoDS_Shell> shells (np);
  vector<double> vol (np, 0);
  vector<Bnd_Box> box (np);
  for (int p = 0; p < np; p++)
  {
    bb.MakeShell (shells[p]);
  }
  for (size_t t = 0; t < nt; t++)
  {
    TopoDS_Wire w;
    bb.MakeWire (w);
    for (int e = 0; e < 3; e++)
    {
      const octave_idx_type a = T[t][e], b = T[t][(e + 1) % 3];
      const int64_t k = key (a, b);
      auto it = ed.find (k);
      if (it == ed.end ())
      {
        const octave_idx_type lo = std::min (a, b), hi = std::max (a, b);
        it = ed.emplace (k, BRepBuilderAPI_MakeEdge (vertex (lo), vertex (hi))
                              .Edge ()).first;
      }
      bb.Add (w, a < b ? it->second
                       : TopoDS::Edge (it->second.Reversed ()));
    }
    w.Closed (Standard_True);
    const gp_Pnt a (V(T[t][0],0), V(T[t][0],1), V(T[t][0],2));
    const gp_Pnt b (V(T[t][1],0), V(T[t][1],1), V(T[t][1],2));
    const gp_Pnt c (V(T[t][2],0), V(T[t][2],1), V(T[t][2],2));
    const gp_Vec n = gp_Vec (a, b).Crossed (gp_Vec (a, c));
    TopoDS_Face f;
    bb.MakeFace (f, new Geom_Plane (a, gp_Dir (n)), Precision::Confusion ());
    bb.Add (f, w);
    bb.Add (shells[piece[t]], f);
    box[piece[t]].Add (a);
    box[piece[t]].Add (b);
    box[piece[t]].Add (c);
    vol[piece[t]] += gp_Vec (a.XYZ ()).Dot (gp_Vec (b.XYZ ())
                                            .Crossed (gp_Vec (c.XYZ ()))) / 6;
  }

  // Pieces enclosing volume are solids; one running the other way is a void
  // in the solid around it, or a solid turned inside out when none is
  vector<TopoDS_Solid> solids;
  vector<Bnd_Box> boxes;
  for (int p = 0; p < np; p++)
  {
    shells[p].Closed (Standard_True);
    if (vol[p] > 0)
    {
      TopoDS_Solid so;
      bb.MakeSolid (so);
      bb.Add (so, shells[p]);
      solids.push_back (so);
      boxes.push_back (box[p]);
    }
  }
  for (int p = 0; p < np; p++)
  {
    if (vol[p] > 0)
    {
      continue;
    }
    gp_Pnt q;
    for (size_t t = 0; t < nt; t++)
    {
      if (piece[t] == p)
      {
        q = gp_Pnt (V(T[t][0],0), V(T[t][0],1), V(T[t][0],2));
        break;
      }
    }
    bool held = false;
    for (TopoDS_Solid& so : solids)
    {
      BRepClass3d_SolidClassifier cls (so, q, 1e-9);
      if (cls.State () == TopAbs_IN)
      {
        bb.Add (so, shells[p]);
        held = true;
        break;
      }
    }
    if (! held)
    {
      TopoDS_Solid so;
      bb.MakeSolid (so);
      bb.Add (so, TopoDS::Shell (shells[p].Reversed ()));
      solids.push_back (so);
      boxes.push_back (box[p]);
    }
  }

  // Solids that may overlap are united; apart, they stay as they are, which
  // spares a large mesh in one piece the boolean
  bool apart = true;
  for (size_t i = 0; i < solids.size () && apart; i++)
  {
    for (size_t j = i + 1; j < solids.size () && apart; j++)
    {
      apart = boxes[i].IsOut (boxes[j]);
    }
  }
  TopoDS_Shape s;
  if (solids.size () == 1)
  {
    s = solids[0];
  }
  else if (apart)
  {
    TopoDS_Compound c;
    bb.MakeCompound (c);
    for (const TopoDS_Solid& so : solids)
    {
      bb.Add (c, so);
    }
    s = c;
  }
  else
  {
    TopTools_ListOfShape objects, tools;
    objects.Append (solids[0]);
    for (size_t i = 1; i < solids.size (); i++)
    {
      tools.Append (solids[i]);
    }
    BRepAlgoAPI_Fuse op;
    op.SetArguments (objects);
    op.SetTools (tools);
    op.Build ();
    if (op.HasErrors () || ! op.IsDone ())
    {
      error ("%s: Open CASCADE could not unite the pieces of the mesh.",
             caller.c_str ());
    }
    s = op.Shape ();
  }
  if (merge)
  {
    ShapeUpgrade_UnifySameDomain u (s, Standard_True, Standard_True,
                                    Standard_False);
    u.Build ();
    s = u.Shape ();
  }
  return s;
}

// A face through the grid of points X, Y and Z, M by N, an exact B-spline
// surface passing within 0.001 of every point.  The column index runs along u
// and the row index along v, so the normal is the step to the next column
// crossed with the step to the next row.  The parameters are spaced evenly by
// index, as a grid is made: spaced by chord length, or interpolating every
// point, the surface ripples near the edges of a fine grid.  With H1 or H2
// positive it is a solid, the face thickened H1 along the normal and H2
// against it, refused where the surface curves more tightly than the
// thickness reaching that side.
static TopoDS_Shape
gridsurface (const Matrix& X, const Matrix& Y, const Matrix& Z, double h1,
             double h2, const string& caller)
{
  const octave_idx_type m = X.rows ();
  const octave_idx_type n = X.columns ();
  TColgp_Array2OfPnt P (1, n, 1, m);
  for (octave_idx_type j = 0; j < n; j++)
  {
    for (octave_idx_type i = 0; i < m; i++)
    {
      P.SetValue (j + 1, i + 1, gp_Pnt (X(i,j), Y(i,j), Z(i,j)));
    }
  }
  GeomAPI_PointsToBSplineSurface fit;
  fit.Init (P, Approx_IsoParametric, 3, 8, GeomAbs_C2, 1e-3);
  if (! fit.IsDone ())
  {
    error ("%s: Open CASCADE could not fit a surface through the grid.",
           caller.c_str ());
  }
  const Handle (Geom_BSplineSurface) bs = fit.Surface ();
  const TopoDS_Face face = BRepBuilderAPI_MakeFace (bs,
                                                    Precision::Confusion ());
  if (h1 == 0 && h2 == 0)
  {
    return face;
  }

  // The tightest radius on each side of the surface, sampled four times
  // across every cell of the grid.  A curvature is positive where the surface
  // bends towards its normal.
  double u1, u2, v1, v2;
  bs->Bounds (u1, u2, v1, v2);
  const int nu = 4 * (n - 1) + 1;
  const int nv = 4 * (m - 1) + 1;
  double along = 0;
  double against = 0;
  GeomLProp_SLProps props (bs, 2, Precision::Confusion ());
  for (int a = 0; a < nu; a++)
  {
    for (int b = 0; b < nv; b++)
    {
      props.SetParameters (u1 + (u2 - u1) * a / (nu - 1),
                           v1 + (v2 - v1) * b / (nv - 1));
      if (props.IsCurvatureDefined ())
      {
        const double k1 = props.MaxCurvature ();
        const double k2 = props.MinCurvature ();
        along = max ({along, k1, k2});
        against = max ({against, -k1, -k2});
      }
    }
  }
  if (h1 > 0 && h1 * along >= 1)
  {
    error ("%s: the surface curves more tightly than the thickness along its"
           " normal allows; its tightest radius on that side is %.3g.",
           caller.c_str (), 1 / along);
  }
  if (h2 > 0 && h2 * against >= 1)
  {
    error ("%s: the surface curves more tightly than the thickness against"
           " its normal allows; its tightest radius on that side is %.3g.",
           caller.c_str (), 1 / against);
  }

  // Thickened from one side: a face moved back by H2 first when both
  // sides are thick
  TopoDS_Shape base = face;
  if (h1 > 0 && h2 > 0)
  {
    BRepOffsetAPI_MakeOffsetShape off;
    off.PerformBySimple (face, -h2);
    base = off.Shape ();
  }
  BRepOffsetAPI_MakeThickSolid thick;
  thick.MakeThickSolidBySimple (base, (h1 > 0 ? h1 + h2 : -h2));
  thick.Build ();
  if (! thick.IsDone () || thick.Shape ().ShapeType () != TopAbs_SOLID)
  {
    error ("%s: Open CASCADE could not thicken the surface.", caller.c_str ());
  }
  // Thickened along the normal, the solid comes out turned inwards
  TopoDS_Solid so = TopoDS::Solid (thick.Shape ());
  BRepLib::OrientClosedSolid (so);
  return so;
}

// A transformed copy of a shape
static TopoDS_Shape
transform (const TopoDS_Shape& s, const gp_Trsf& t)
{
  return BRepBuilderAPI_Transform (s, t, Standard_True).Shape ();
}

// The transformation into the frame F, rows origin, x axis, y axis and
// normal, where its plane is z = 0
static gp_Trsf
intoframe (const Matrix& f)
{
  gp_Trsf t;
  t.SetTransformation (gp_Ax3 (gp_Pnt (f(0,0), f(0,1), f(0,2)),
                               gp_Dir (f(3,0), f(3,1), f(3,2)),
                               gp_Dir (f(1,0), f(1,1), f(1,2))));
  return t;
}

// The wire W of an offset made with round corners, in the plane z = 0, each
// corner arc of radius D about a vertex of the face F between two straight
// edges replaced by the line square to the corner that touches the arc in
// its middle, the edges either side carried on to meet it
static TopoDS_Wire
chamferwire (const TopoDS_Wire& w, const TopoDS_Face& f, double d)
{
  vector<gp_Pnt> corners;
  for (TopExp_Explorer x (f, TopAbs_VERTEX); x.More (); x.Next ())
  {
    corners.push_back (BRep_Tool::Pnt (TopoDS::Vertex (x.Current ())));
  }
  // The edges in turn, each with its start and end the way the wire runs
  struct ed
  {
    TopoDS_Edge e;
    gp_Pnt a, b;
    bool line, corner = false;
    gp_Pnt c1, c2;
  };
  vector<ed> E;
  for (BRepTools_WireExplorer x (w); x.More (); x.Next ())
  {
    ed g;
    g.e = x.Current ();
    g.a = BRep_Tool::Pnt (TopExp::FirstVertex (g.e, Standard_True));
    g.b = BRep_Tool::Pnt (TopExp::LastVertex (g.e, Standard_True));
    const BRepAdaptor_Curve c (g.e);
    g.line = (c.GetType () == GeomAbs_Line);
    if (c.GetType () == GeomAbs_Circle && std::abs (c.Circle ().Radius () - d)
                                          <= 1e-7 * (1 + d))
    {
      for (const gp_Pnt& p : corners)
      {
        g.corner = g.corner || p.Distance (c.Circle ().Location ())
                               <= 1e-7 * (1 + d);
      }
    }
    E.push_back (g);
  }
  const size_t n = E.size ();
  for (size_t i = 0; i < n; i++)
  {
    ed& g = E[i];
    ed& p = E[(i + n - 1) % n];
    ed& q = E[(i + 1) % n];
    if (! g.corner || ! p.line || ! q.line || n < 3)
    {
      g.corner = false;
      continue;
    }
    // The chamfer touches the arc where it is half way round
    double u0, u1;
    const Handle (Geom_Curve) c = BRep_Tool::Curve (g.e, u0, u1);
    const gp_Pnt m = c->Value ((u0 + u1) / 2);
    gp_Vec t;
    gp_Pnt dummy;
    c->D1 ((u0 + u1) / 2, dummy, t);
    // Where the chamfer line meets the lines of the edges either side
    auto meet = [&] (const gp_Pnt& a, const gp_Pnt& b)
    {
      const gp_Vec u (a, b);
      const gp_Vec w0 (a, m);
      const double den = u.X () * t.Y () - u.Y () * t.X ()
                         + 1e-300;
      const double s = (w0.X () * t.Y () - w0.Y () * t.X ()) / den;
      return gp_Pnt (a.XYZ () + s * u.XYZ ());
    };
    g.c1 = meet (p.a, p.b);
    g.c2 = meet (q.a, q.b);
    p.b = g.c1;
    q.a = g.c2;
  }
  BRepBuilderAPI_MakeWire mw;
  for (size_t i = 0; i < n; i++)
  {
    const ed& g = E[i];
    if (g.corner)
    {
      mw.Add (BRepBuilderAPI_MakeEdge (g.c1, g.c2).Edge ());
    }
    else if (g.line)
    {
      mw.Add (BRepBuilderAPI_MakeEdge (g.a, g.b).Edge ());
    }
    else
    {
      mw.Add (g.e);
    }
  }
  return mw.IsDone () ? mw.Wire () : w;
}

// The signed area inside the wire W in the plane z = 0, positive where it
// runs anticlockwise, from points along each edge in turn
static double
wirearea (const TopoDS_Wire& w)
{
  double a = 0;
  for (BRepTools_WireExplorer x (w); x.More (); x.Next ())
  {
    const BRepAdaptor_Curve c (x.Current ());
    const bool rev = (x.Current ().Orientation () == TopAbs_REVERSED);
    const double u0 = c.FirstParameter (), u1 = c.LastParameter ();
    const int n = 64;
    gp_Pnt p = c.Value (rev ? u1 : u0);
    for (int k = 1; k <= n; k++)
    {
      const double t = rev ? u1 - (u1 - u0) * k / n : u0 + (u1 - u0) * k / n;
      const gp_Pnt q = c.Value (t);
      a += (p.X () * q.Y () - q.X () * p.Y ()) / 2;
      p = q;
    }
  }
  return a;
}

// The faces of C, lying in the plane z = 0, each as its outer loop and its
// inner loops, in pieces as sectionloop gives them; faces whose area is
// nothing beside SCALE left out
static Cell
facesout (const TopoDS_Shape& c, double scale)
{
  vector<octave_value> faces;
  for (TopExp_Explorer x (c, TopAbs_FACE); x.More (); x.Next ())
  {
    const TopoDS_Face face = TopoDS::Face (x.Current ());
    GProp_GProps p;
    BRepGProp::SurfaceProperties (face, p);
    if (p.Mass () <= 1e-12 * scale)
    {
      continue;
    }
    const TopoDS_Wire outer = BRepTools::OuterWire (face);
    vector<octave_value> holes;
    for (TopExp_Explorer y (face, TopAbs_WIRE); y.More (); y.Next ())
    {
      if (! y.Current ().IsSame (outer))
      {
        holes.push_back (sectionloop (TopoDS::Wire (y.Current ()), face));
      }
    }
    Cell h (1, holes.size ());
    for (size_t i = 0; i < holes.size (); i++)
    {
      h(i) = holes[i];
    }
    octave_scalar_map m;
    m.assign ("outline", sectionloop (outer, face));
    m.assign ("holes", h);
    faces.push_back (m);
  }
  Cell out (1, faces.size ());
  for (size_t i = 0; i < faces.size (); i++)
  {
    out(i) = faces[i];
  }
  return out;
}

// The face F without the edges lying inside it, such as an edge drawn on a
// projection that ends within the outline; a wire left with none is dropped
static TopoDS_Face
withoutinternal (const TopoDS_Face& f)
{
  BRep_Builder b;
  TopoDS_Face g = TopoDS::Face (f.EmptyCopied ());
  for (TopoDS_Iterator w (f, Standard_False, Standard_False); w.More ();
       w.Next ())
  {
    TopoDS_Wire nw;
    b.MakeWire (nw);
    int n = 0;
    for (TopoDS_Iterator e (w.Value (), Standard_False, Standard_False);
         e.More (); e.Next ())
    {
      const TopAbs_Orientation o = e.Value ().Orientation ();
      if (o == TopAbs_FORWARD || o == TopAbs_REVERSED)
      {
        b.Add (nw, e.Value ());
        n++;
      }
    }
    if (n > 0)
    {
      nw.Orientation (w.Value ().Orientation ());
      nw.Closed (Standard_True);
      b.Add (g, nw);
    }
  }
  return g;
}

// The edge E in pieces turning through a quarter turn at most, so that no
// piece runs over itself, as the outline of a coil seen along its axis would
static vector<TopoDS_Edge>
turns (const TopoDS_Edge& e)
{
  double a, b;
  const Handle (Geom_Curve) c = BRep_Tool::Curve (e, a, b);
  if (c.IsNull () || BRep_Tool::Degenerated (e))
  {
    return {e};
  }
  const BRepAdaptor_Curve g (e);
  if (g.GetType () == GeomAbs_Line)
  {
    return {e};
  }
  // The turning, from the tangent at many points along it
  const int m = 256;
  double turn = 0;
  gp_Vec t0;
  bool have = false;
  for (int i = 0; i <= m; i++)
  {
    gp_Pnt p;
    gp_Vec t;
    c->D1 (a + i * (b - a) / m, p, t);
    if (t.Magnitude () < gp::Resolution ())
    {
      continue;
    }
    if (have)
    {
      turn += t0.Angle (t);
    }
    t0 = t;
    have = true;
  }
  const int n = std::ceil (turn / (M_PI / 2) - 1e-9);
  if (n <= 1)
  {
    return {e};
  }
  vector<TopoDS_Edge> out;
  for (int i = 0; i < n; i++)
  {
    out.push_back (BRepBuilderAPI_MakeEdge (c, a + i * (b - a) / n,
                                            a + (i + 1) * (b - a) / n).Edge ());
  }
  return out;
}

// Whether the edge E lies along the edges TAKEN, each with its box, every
// one of a few points along it within TOL of one of them
static bool
covered (const TopoDS_Edge& e, const vector<pair<Bnd_Box, TopoDS_Edge>>& taken,
         double tol)
{
  if (BRep_Tool::Degenerated (e))
  {
    return true;
  }
  if (taken.empty ())
  {
    return false;
  }
  BRepAdaptor_Curve g (e);
  const double a = g.FirstParameter ();
  const double b = g.LastParameter ();
  ShapeAnalysis_Curve sa;
  for (int i = 0; i <= 8; i++)
  {
    const gp_Pnt p = g.Value (a + i * (b - a) / 8);
    bool near = false;
    for (size_t k = 0; k < taken.size () && ! near; k++)
    {
      if (taken[k].first.IsOut (p))
      {
        continue;
      }
      double f, l;
      const Handle (Geom_Curve) c = BRep_Tool::Curve (taken[k].second, f, l);
      gp_Pnt q;
      double t;
      near = (! c.IsNull ()
              && sa.Project (c, p, tol, q, t, f, l) <= tol);
    }
    if (! near)
    {
      return false;
    }
  }
  return true;
}

// Whether the edge E is straight to within TOL, its points on the chord
// between its ends
static bool
straight (const TopoDS_Edge& e, double tol)
{
  const BRepAdaptor_Curve g (e);
  if (g.GetType () == GeomAbs_Line)
  {
    return true;
  }
  const gp_Pnt p = g.Value (g.FirstParameter ());
  const gp_Pnt q = g.Value (g.LastParameter ());
  const gp_Vec d (p, q);
  if (d.Magnitude () <= tol)
  {
    return false;
  }
  for (const double t : {0.25, 0.5, 0.75})
  {
    const gp_Pnt m = g.Value (g.FirstParameter ()
                              + t * (g.LastParameter () - g.FirstParameter ()));
    if (gp_Vec (p, m).Crossed (d).Magnitude () / d.Magnitude () > tol)
    {
      return false;
    }
  }
  return true;
}

// The face F of the plane z = 0 with every run of straight edges that lie
// end to end on one line joined into one line, and a straight edge held as
// another curve, as a circle seen edge on is, made a line; every other edge
// is kept
static TopoDS_Face
joinstraight (const TopoDS_Face& f, double tol)
{
  const TopoDS_Wire outer = BRepTools::OuterWire (f);
  vector<TopoDS_Wire> wires;
  bool changed = false;
  for (TopoDS_Iterator w (f); w.More (); w.Next ())
  {
    const TopoDS_Wire wire = TopoDS::Wire (w.Value ());

    // The edges in order round the wire, each with its ends as it runs
    vector<TopoDS_Edge> E;
    vector<gp_Pnt> P, Q;
    vector<bool> S, L;
    for (BRepTools_WireExplorer x (wire); x.More (); x.Next ())
    {
      const TopoDS_Edge e = x.Current ();
      E.push_back (e);
      P.push_back (BRep_Tool::Pnt (TopExp::FirstVertex (e, Standard_True)));
      Q.push_back (BRep_Tool::Pnt (TopExp::LastVertex (e, Standard_True)));
      S.push_back (straight (e, tol));
      L.push_back (BRepAdaptor_Curve (e).GetType () == GeomAbs_Line);
    }
    const size_t n = E.size ();

    // Whether edge k runs on along the line of the edge before it
    auto runson = [&] (size_t k)
    {
      const size_t i = (k + n - 1) % n;
      if (! S[i] || ! S[k])
      {
        return false;
      }
      const gp_Vec d (P[i], Q[i]);
      return gp_Vec (P[i], Q[k]).Crossed (d).Magnitude () / d.Magnitude ()
             <= tol && gp_Vec (P[k], Q[k]).Dot (d) > 0;
    };
    size_t start = n;
    for (size_t k = 0; k < n; k++)
    {
      if (! runson (k))
      {
        start = k;
        break;
      }
    }
    bool work = false;
    for (size_t k = 0; k < n; k++)
    {
      work = work || (S[k] && ! L[k]) || runson (k);
    }
    if (n < 2 || start == n || ! work)
    {
      if (wire.IsSame (outer))
      {
        wires.insert (wires.begin (), wire);
      }
      else
      {
        wires.push_back (wire);
      }
      continue;
    }

    BRepBuilderAPI_MakeWire mw;
    size_t k = 0;
    while (k < n)
    {
      const size_t a = (start + k) % n;
      size_t m = 1;
      while (k + m < n && runson ((start + k + m) % n))
      {
        m++;
      }
      if (m == 1 && ! (S[a] && ! L[a]))
      {
        mw.Add (E[a]);
      }
      else
      {
        mw.Add (BRepBuilderAPI_MakeEdge (P[a], Q[(start + k + m - 1) % n])
                .Edge ());
        changed = true;
      }
      k += m;
    }
    if (! mw.IsDone ())
    {
      return f;
    }
    TopoDS_Wire nw = mw.Wire ();
    if (wire.IsSame (outer))
    {
      wires.insert (wires.begin (), nw);
    }
    else
    {
      wires.push_back (nw);
    }
  }
  if (! changed)
  {
    return f;
  }

  // The wires laid on the plane again, the outline first and the holes in it
  BRepBuilderAPI_MakeFace mf (gp_Pln (gp::XOY ()), wires[0]);
  for (size_t i = 1; i < wires.size (); i++)
  {
    mf.Add (wires[i]);
  }
  if (! mf.IsDone ())
  {
    return f;
  }
  return mf.Face ();
}

// The outline of the shape S seen along z, on the plane z = 0, as facesout
// gives it
static Cell
projection (const TopoDS_Shape& s, const string& caller)
{
  Bnd_Box box;
  BRepBndLib::Add (s, box);
  if (box.IsVoid ())
  {
    return Cell (1, 0);
  }
  double x0, y0, z0, x1, y1, z1;
  box.Get (x0, y0, z0, x1, y1, z1);
  const double size = (x1 - x0) + (y1 - y0) + (z1 - z0);

  Handle (HLRBRep_Algo) hlr = new HLRBRep_Algo ();
  hlr->Add (s);
  hlr->Projector (HLRAlgo_Projector (gp_Ax2 (gp::Origin (), gp::DZ (),
                                             gp::DX ())));
  hlr->Update ();
  hlr->ShowAll ();
  HLRBRep_HLRToShape h (hlr);

  // Every edge and outline, hidden or not, since what is hidden is not always
  // told right where a face is seen edge on; one lying along those taken is
  // left out, as the turns of a coil seen along its axis are
  const double tol = 1e-5 * size;
  TopTools_ListOfShape tools;
  vector<pair<Bnd_Box, TopoDS_Edge>> taken;
  for (const TopoDS_Shape& c : {h.VCompound (), h.OutLineVCompound (),
                                h.Rg1LineVCompound (), h.RgNLineVCompound (),
                                h.HCompound (), h.OutLineHCompound (),
                                h.Rg1LineHCompound (), h.RgNLineHCompound ()})
  {
    if (c.IsNull ())
    {
      continue;
    }
    BRepLib::BuildCurves3d (c);
    for (TopExp_Explorer x (c, TopAbs_EDGE); x.More (); x.Next ())
    {
      for (const TopoDS_Edge& e : turns (TopoDS::Edge (x.Current ())))
      {
        if (covered (e, taken, tol))
        {
          continue;
        }
        Bnd_Box b;
        BRepBndLib::Add (e, b);
        b.Enlarge (tol);
        taken.push_back ({b, e});
        tools.Append (e);
      }
    }
  }
  if (tools.IsEmpty ())
  {
    return Cell (1, 0);
  }

  const double r = 1 + (x1 - x0) + (y1 - y0);
  const TopoDS_Face plane
    = BRepBuilderAPI_MakeFace (gp_Pln (gp::XOY ()), x0 - r, x1 + r,
                               y0 - r, y1 + r).Face ();
  TopTools_ListOfShape objects;
  objects.Append (plane);
  BRepAlgoAPI_Splitter sp;
  sp.SetArguments (objects);
  sp.SetTools (tools);
  sp.SetFuzzyValue (tol);
  sp.Build ();
  if (sp.HasErrors () || ! sp.IsDone ())
  {
    error ("%s: Open CASCADE could not compute the projection.",
           caller.c_str ());
  }

  Handle (IntTools_Context) ctx = new IntTools_Context ();
  BRep_Builder b;
  TopoDS_Compound kept;
  b.MakeCompound (kept);
  int n = 0;
  for (TopExp_Explorer x (sp.Shape (), TopAbs_FACE); x.More (); x.Next ())
  {
    const TopoDS_Face face = TopoDS::Face (x.Current ());
    gp_Pnt p;
    gp_Pnt2d q;
    if (BOPTools_AlgoTools3D::PointInFace (face, p, q, ctx) != 0)
    {
      GProp_GProps g;
      BRepGProp::SurfaceProperties (face, g);
      if (std::abs (g.Mass ()) > 1e-12 * (x1 - x0) * (y1 - y0))
      {
        error ("%s: Open CASCADE could not compute the projection.",
               caller.c_str ());
      }
      continue;
    }
    BRepIntCurveSurface_Inter hit;
    hit.Init (s, gp_Lin (p, gp::DZ ()), Precision::Confusion ());
    if (hit.More ())
    {
      b.Add (kept, face);
      n++;
    }
  }
  if (n == 0)
  {
    return Cell (1, 0);
  }
  ShapeUpgrade_UnifySameDomain u (kept, Standard_True, Standard_True,
                                  Standard_False);
  u.Build ();
  TopoDS_Compound c;
  b.MakeCompound (c);
  for (TopExp_Explorer x (u.Shape (), TopAbs_FACE); x.More (); x.Next ())
  {
    b.Add (c, withoutinternal (TopoDS::Face (x.Current ())));
  }

  // A circle seen edge on leaves a straight edge held as a curve, or pieces
  // of one line
  TopoDS_Compound j;
  b.MakeCompound (j);
  for (TopExp_Explorer x (c, TopAbs_FACE); x.More (); x.Next ())
  {
    b.Add (j, joinstraight (TopoDS::Face (x.Current ()), tol));
  }
  return facesout (j, (x1 - x0) * (y1 - y0) + 1);
}

// The solids of S, in the order a map of them gives
static TopTools_IndexedMapOfShape
solidsof (const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes (s, TopAbs_SOLID, m);
  return m;
}

// The solids each solid of a result came from, as indices from 1 into the
// solids of the operands, those of each in turn in the order a map of them
// gives
typedef vector<std::set<int>> origins;

// Where each solid of R came from: the solids of SOURCES that any of its
// faces is, or was made by OP from, a face or an edge of
static origins
lineage (BRepBuilderAPI_MakeShape& op, const vector<TopoDS_Shape>& sources,
         const TopoDS_Shape& r)
{
  TopTools_DataMapOfShapeInteger owner;
  auto claim = [&owner] (const TopoDS_Shape& f, int k)
  {
    if (f.ShapeType () == TopAbs_FACE
        && (! owner.IsBound (f) || owner (f) > k))
    {
      owner.UnBind (f);
      owner.Bind (f, k);
    }
  };
  int k = 0;
  for (const TopoDS_Shape& src : sources)
  {
    const TopTools_IndexedMapOfShape solids = solidsof (src);
    for (int i = 1; i <= solids.Extent (); i++)
    {
      k++;
      for (TopExp_Explorer x (solids (i), TopAbs_FACE); x.More (); x.Next ())
      {
        claim (x.Current (), k);
        for (const TopoDS_Shape& f : op.Modified (x.Current ()))
        {
          claim (f, k);
        }
        for (const TopoDS_Shape& f : op.Generated (x.Current ()))
        {
          claim (f, k);
        }
      }
      for (TopExp_Explorer x (solids (i), TopAbs_EDGE); x.More (); x.Next ())
      {
        for (const TopoDS_Shape& f : op.Generated (x.Current ()))
        {
          claim (f, k);
        }
      }
    }
  }
  const TopTools_IndexedMapOfShape rs = solidsof (r);
  origins L (rs.Extent ());
  for (int i = 1; i <= rs.Extent (); i++)
  {
    for (TopExp_Explorer x (rs (i), TopAbs_FACE); x.More (); x.Next ())
    {
      if (owner.IsBound (x.Current ()))
      {
        L[i-1].insert (owner (x.Current ()));
      }
    }
  }
  return L;
}

// Where each solid of R came from, as lineage gives it, for an operation
// that keeps no history: the solids of S whose boxes meet the solid's
static origins
overlap (const TopoDS_Shape& s, const TopoDS_Shape& r)
{
  const TopTools_IndexedMapOfShape from = solidsof (s);
  const TopTools_IndexedMapOfShape rs = solidsof (r);
  origins L (rs.Extent ());
  for (int i = 1; i <= rs.Extent (); i++)
  {
    Bnd_Box b;
    BRepBndLib::Add (rs (i), b);
    for (int j = 1; j <= from.Extent (); j++)
    {
      Bnd_Box a;
      BRepBndLib::Add (from (j), a);
      if (! a.IsOut (b))
      {
        L[i-1].insert (j);
      }
    }
  }
  return L;
}

// Each solid of a shape of N solids from the solid of the same number
static origins
itself (int n)
{
  origins L (n);
  for (int j = 0; j < n; j++)
  {
    L[j].insert (j + 1);
  }
  return L;
}

// A shape's bytes and where its solids came from, as the commands that
// change solids return them: a row for each solid of the solids it came
// from, in increasing order, padded with 0
static Cell
traced (const TopoDS_Shape& r, const origins& L)
{
  size_t k = 0;
  for (const auto& o : L)
  {
    k = std::max (k, o.size ());
  }
  Matrix M (L.size (), k, 0.0);
  for (size_t i = 0; i < L.size (); i++)
  {
    size_t j = 0;
    for (int o : L[i])
    {
      M(i,j++) = o;
    }
  }
  Cell c (1, 2);
  c(0) = todata (r);
  c(1) = M;
  return c;
}

// The result of a boolean operation, its coplanar faces and collinear edges
// merged so that a union of two blocks reads as one block.
static TopoDS_Shape
boolean (BRepAlgoAPI_BooleanOperation& op, const string& caller,
         const char *what)
{
  op.Build ();
  if (op.HasErrors () || ! op.IsDone ())
  {
    error ("%s: Open CASCADE could not compute the %s.", caller.c_str (),
           what);
  }
  op.SimplifyResult ();
  return op.Shape ();
}

static TopoDS_Shape
cutall (const TopoDS_Shape& s, const vector<TopoDS_Shape>& tools,
        const string& caller)
{
  if (tools.empty ())
  {
    return s;
  }
  TopTools_ListOfShape objects, list;
  objects.Append (s);
  for (const TopoDS_Shape& t : tools)
  {
    list.Append (t);
  }
  BRepAlgoAPI_Cut op;
  op.SetArguments (objects);
  op.SetTools (list);
  return boolean (op, caller, "holes");
}

// A wire swept along SPINE into a solid, with sharp corners or, along a
// helix, the Frenet frame
static TopoDS_Shape
pipe (const TopoDS_Wire& spine, const TopoDS_Wire& w, bool frenet,
      const string& caller)
{
  BRepOffsetAPI_MakePipeShell op (spine);
  if (frenet)
  {
    op.SetMode (Standard_True);
  }
  else
  {
    op.SetTransitionMode (BRepBuilderAPI_RightCorner);
  }
  op.Add (w);
  op.Build ();
  if (! op.IsDone () || ! op.MakeSolid ())
  {
    error ("%s: Open CASCADE could not compute the sweep.", caller.c_str ());
  }
  return op.Shape ();
}

// A wire offset by D in its plane, outwards for a positive D whichever way
// it runs, its corners kept sharp; then lifted by V
static TopoDS_Wire
offsetwire (const TopoDS_Wire& w, double d, const gp_Vec& v,
            const string& caller)
{
  BRepOffsetAPI_MakeOffset op (w, GeomAbs_Intersection);
  op.Perform (d);
  TopExp_Explorer x;
  if (op.IsDone ())
  {
    x.Init (op.Shape (), TopAbs_WIRE);
  }
  if (! op.IsDone () || ! x.More ())
  {
    error ("%s: Open CASCADE could not compute the taper.", caller.c_str ());
  }
  gp_Trsf t;
  t.SetTranslation (v);
  return TopoDS::Wire (transform (x.Current (), t));
}

// S with every spline face that lies in a plane made a true plane on the
// same edges, so that a flat wall counts as flat when queried, picked or
// drawn.  A ruled loft makes even a flat wall a spline.
static TopoDS_Shape
planarize (const TopoDS_Shape& s)
{
  BRepTools_ReShape rs;
  bool changed = false;
  for (TopExp_Explorer x (s, TopAbs_FACE); x.More (); x.Next ())
  {
    const TopoDS_Face& f = TopoDS::Face (x.Current ());
    const BRepAdaptor_Surface a (f, Standard_False);
    if (a.GetType () != GeomAbs_BSplineSurface
        && a.GetType () != GeomAbs_BezierSurface)
    {
      continue;
    }
    GeomLib_IsPlanarSurface pl (BRep_Tool::Surface (f), 1e-7);
    if (! pl.IsPlanar ())
    {
      continue;
    }
    // The plane facing as the surface does, then the face rebuilt on it and
    // turned as the face is
    gp_Pln p = pl.Plan ();
    const double u = (a.FirstUParameter () + a.LastUParameter ()) / 2;
    const double v = (a.FirstVParameter () + a.LastVParameter ()) / 2;
    BRepLProp_SLProps props (BRepAdaptor_Surface (f), u, v, 1, 1e-9);
    const gp_Dir n = props.Normal ();
    if (p.Axis ().Direction ().Dot (n) < 0)
    {
      p = gp_Pln (p.Location (), p.Axis ().Direction ().Reversed ());
    }
    BRepBuilderAPI_MakeFace mf (p, BRepTools::OuterWire (f), Standard_True);
    for (TopExp_Explorer w (f, TopAbs_WIRE); w.More (); w.Next ())
    {
      if (! w.Current ().IsSame (BRepTools::OuterWire (f)))
      {
        mf.Add (TopoDS::Wire (w.Current ()));
      }
    }
    if (! mf.IsDone ())
    {
      continue;
    }
    TopoDS_Face nf = mf.Face ();
    nf.Orientation (f.Orientation ());
    rs.Replace (f, nf);
    changed = true;
  }
  return changed ? rs.Apply (s) : s;
}

// The solid between a wire and its offset lifted, by straight lines
static TopoDS_Shape
ruled (const TopoDS_Wire& a, const TopoDS_Wire& b, const string& caller)
{
  BRepOffsetAPI_ThruSections op (Standard_True, Standard_True);
  op.AddWire (a);
  op.AddWire (b);
  op.Build ();
  if (! op.IsDone ())
  {
    error ("%s: Open CASCADE could not compute the taper.", caller.c_str ());
  }
  return op.Shape ();
}

static TopoDS_Shape
taperedside (const region& r, double h, double a, const string& caller)
{
  const gp_Vec up = gp_Vec (r.normal) * h;
  if (a == 0)
  {
    return BRepPrimAPI_MakePrism (planarface (r), up).Shape ();
  }
  // The section at the top is the region offset by the run of the wall:
  // its outline in, its holes out, for walls leaning in
  const double d = h * tan (a);
  vector<TopoDS_Shape> holes;
  for (const TopoDS_Wire& w : r.holes)
  {
    holes.push_back (ruled (w, offsetwire (w, d, up, caller), caller));
  }
  return planarize (cutall (ruled (r.outer, offsetwire (r.outer, -d, up,
                                                       caller), caller),
                            holes, caller));
}

// A document of Open CASCADE's framework for names and colours (XDE), in
// millimetres, closed when it goes out of scope
struct xdedoc
{
  Handle (XCAFApp_Application) app = XCAFApp_Application::GetApplication ();
  Handle (TDocStd_Document) doc;

  xdedoc ()
  {
    app->NewDocument ("MDTV-XCAF", doc);
    XCAFDoc_DocumentTool::SetLengthUnit (doc, 0.001);
  }

  ~xdedoc ()
  {
    app->Close (doc);
  }

  Handle (XCAFDoc_ShapeTool) shapes () const
  {
    return XCAFDoc_DocumentTool::ShapeTool (doc->Main ());
  }

  Handle (XCAFDoc_ColorTool) colours () const
  {
    return XCAFDoc_DocumentTool::ColorTool (doc->Main ());
  }
};

// The solids of the part S at the label L of the document D, each in its
// row of COLOURS, red, green and blue from 0 to 1, in the order a map of
// them gives, unless the row is NaN or COLOURS has none
static void
colourpart (const xdedoc& d, const TDF_Label& l, const TopoDS_Shape& s,
            const Matrix& colours)
{
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes (s, TopAbs_SOLID, solids);
  for (int i = 1; i <= solids.Extent () && i <= colours.rows (); i++)
  {
    if (std::isnan (colours(i-1,0)))
    {
      continue;
    }
    const Quantity_Color c (colours(i-1,0), colours(i-1,1), colours(i-1,2),
                            Quantity_TOC_sRGB);
    const TDF_Label sub = solids (i).IsSame (s)
                          ? l : d.shapes ()->AddSubShape (l, solids (i));
    d.colours ()->SetColor (sub, c, XCAFDoc_ColorGen);
  }
}

// The document D written to FILE as STEP in millimetres, its file named NAME
static void
writedoc (const xdedoc& d, const string& file, const string& name,
          const string& caller)
{
  STEPCAFControl_Writer w;
  w.SetColorMode (Standard_True);
  w.SetNameMode (Standard_True);
  Interface_Static::SetCVal ("write.step.unit", "MM");
  if (! w.Transfer (d.doc, STEPControl_AsIs))
  {
    error ("%s: Open CASCADE could not translate the shape to STEP.",
           caller.c_str ());
  }
  APIHeaderSection_MakeHeader header (w.ChangeWriter ().Model ());
  header.SetName (new TCollection_HAsciiString (name.c_str ()));
  header.SetAuthorValue (1, new TCollection_HAsciiString (""));
  header.SetOrganizationValue (1, new TCollection_HAsciiString (""));
  header.SetOriginatingSystem
    (new TCollection_HAsciiString ("GNU Octave drafting package"));
  header.SetAuthorisation (new TCollection_HAsciiString (""));
  if (w.Write (file.c_str ()) != IFSelect_RetDone)
  {
    error ("%s: cannot write '%s'.", caller.c_str (), file.c_str ());
  }
}

// S written to FILE as STEP, one part named NAME, its solids coloured as
// colourpart colours them
static void
writestep (const TopoDS_Shape& s, const string& file, const string& name,
           const Matrix& colours, const string& caller)
{
  xdedoc d;
  const TDF_Label top = d.shapes ()->AddShape (s, Standard_False);
  TDataStd_Name::Set (top, TCollection_ExtendedString (name.c_str (), true));
  colourpart (d, top, s, colours);
  writedoc (d, file, name, caller);
}

// The frame F, its origin, x axis, y axis and normal one after another, as
// the displacement that carries a part from its own coordinates into it
static gp_Trsf
displacement (const double *f)
{
  gp_Trsf t;
  t.SetDisplacement (gp_Ax3 (gp::XOY ()),
                     gp_Ax3 (gp_Pnt (f[0], f[1], f[2]),
                             gp_Dir (f[9], f[10], f[11]),
                             gp_Dir (f[3], f[4], f[5])));
  return t;
}

// The name a label carries, or empty
static string
labelname (const TDF_Label& l)
{
  Handle (TDataStd_Name) n;
  if (! l.FindAttribute (TDataStd_Name::GetID (), n))
  {
    return "";
  }
  return TCollection_AsciiString (n->Get ()).ToCString ();
}

// An assembly written to FILE as STEP, given as definitions, those it places
// before it and the whole last: each named in NAMES, a part by its bytes in
// DATA and the colours of its solids in COLOURS, an assembly by an empty
// DATA, its placed definitions in CHILDREN, a row for each of the index from
// 1 of the definition and the frame it is placed in, as displacement takes
// it, and the names of those placements in INSTANCES
static void
writeassembly (const string& file, const Cell& names, const Cell& data,
               const Cell& colours, const Cell& children,
               const Cell& instances, const string& caller)
{
  xdedoc d;
  const octave_idx_type n = names.numel ();
  vector<TDF_Label> label (n);
  for (octave_idx_type i = 0; i < n; i++)
  {
    if (! data(i).isempty ())
    {
      const TopoDS_Shape s = toshape (data(i), caller);
      label[i] = d.shapes ()->AddShape (s, Standard_False);
      colourpart (d, label[i], s, colours(i).matrix_value ());
    }
    else
    {
      label[i] = d.shapes ()->NewShape ();
      const Matrix C = children(i).matrix_value ();
      const Cell inst = instances(i).cell_value ();
      for (octave_idx_type k = 0; k < C.rows (); k++)
      {
        double f[12];
        for (int j = 0; j < 12; j++)
        {
          f[j] = C(k,j+1);
        }
        const TDF_Label c
          = d.shapes ()->AddComponent (label[i],
                                       label[static_cast<int> (C(k,0)) - 1],
                                       TopLoc_Location (displacement (f)));
        TDataStd_Name::Set (c, TCollection_ExtendedString
                                 (inst(k).string_value ().c_str (), true));
      }
    }
    TDataStd_Name::Set (label[i], TCollection_ExtendedString
                                    (names(i).string_value ().c_str (),
                                     true));
  }
  d.shapes ()->UpdateAssemblies ();
  writedoc (d, file, names(n-1).string_value (), caller);
}

// The triangles of a mesh of S that strays no further than TOL from its
// surface, nor spans more than ANGLE radians of it: a cell of the points,
// N-by-3, the triangles, K-by-3 indices into them from 1, each turned
// outwards, and the solid each lies on, a K-by-1 index from 1 into a map of
// them, 0 for a face of no solid.  Every face keeps points of its own; those
// along an edge that two faces share are equal, and are welded by the
// caller.
static Cell
tessellation (const TopoDS_Shape& s, double tol, double angle,
              const string& caller)
{
  BRepMesh_IncrementalMesh mesh (s, tol, Standard_False, angle,
                                 Standard_True);
  if (! mesh.IsDone ())
  {
    error ("%s: Open CASCADE could not triangulate the shape.",
           caller.c_str ());
  }
  // Each face with the solid it bounds, the faces of no solid last
  const TopTools_IndexedMapOfShape solids = solidsof (s);
  vector<std::pair<TopoDS_Shape, int>> faces;
  TopTools_IndexedMapOfShape seen;
  for (int k = 1; k <= solids.Extent (); k++)
  {
    for (TopExp_Explorer x (solids (k), TopAbs_FACE); x.More (); x.Next ())
    {
      faces.push_back ({x.Current (), k});
      seen.Add (x.Current ());
    }
  }
  for (TopExp_Explorer x (s, TopAbs_FACE); x.More (); x.Next ())
  {
    if (! seen.Contains (x.Current ()))
    {
      faces.push_back ({x.Current (), 0});
    }
  }
  vector<gp_Pnt> p;
  vector<int> t;
  vector<int> on;
  for (const auto& fk : faces)
  {
    const TopoDS_Face& f = TopoDS::Face (fk.first);
    TopLoc_Location loc;
    Handle (Poly_Triangulation) T = BRep_Tool::Triangulation (f, loc);
    if (T.IsNull ())
    {
      continue;
    }
    const gp_Trsf tr = loc.Transformation ();
    const bool flip = (f.Orientation () == TopAbs_REVERSED)
                      != tr.IsNegative ();
    const int base = p.size ();
    for (int i = 1; i <= T->NbNodes (); i++)
    {
      p.push_back (T->Node (i).Transformed (tr));
    }
    for (int i = 1; i <= T->NbTriangles (); i++)
    {
      int a, b, c;
      T->Triangle (i).Get (a, b, c);
      if (flip)
      {
        std::swap (b, c);
      }
      t.insert (t.end (), {base + a, base + b, base + c});
      on.push_back (fk.second);
    }
  }
  Matrix P (p.size (), 3);
  for (size_t i = 0; i < p.size (); i++)
  {
    P(i,0) = p[i].X ();
    P(i,1) = p[i].Y ();
    P(i,2) = p[i].Z ();
  }
  Matrix F (t.size () / 3, 3);
  for (size_t i = 0; i < t.size (); i++)
  {
    F(i / 3, i % 3) = t[i];
  }
  Matrix K (on.size (), 1);
  for (size_t i = 0; i < on.size (); i++)
  {
    K(i) = on[i];
  }
  Cell c (1, 3);
  c(0) = P;
  c(1) = F;
  c(2) = K;
  return c;
}

// The points of the surface of S: the nodes of a triangulation that strays
// no further than TOL from it, so the hull of the points lies within TOL of
// the hull of S
static Matrix
surfacepoints (const TopoDS_Shape& s, double tol, double angle,
               const string& caller)
{
  BRepMesh_IncrementalMesh mesh (s, tol, Standard_False, angle,
                                 Standard_True);
  if (! mesh.IsDone ())
  {
    error ("%s: Open CASCADE could not triangulate the shape.",
           caller.c_str ());
  }
  vector<gp_Pnt> p;
  for (TopExp_Explorer ex (s, TopAbs_FACE); ex.More (); ex.Next ())
  {
    TopLoc_Location loc;
    Handle (Poly_Triangulation) T
      = BRep_Tool::Triangulation (TopoDS::Face (ex.Current ()), loc);
    if (T.IsNull ())
    {
      continue;
    }
    const gp_Trsf t = loc.Transformation ();
    for (int i = 1; i <= T->NbNodes (); i++)
    {
      p.push_back (T->Node (i).Transformed (t));
    }
  }
  Matrix P (p.size (), 3);
  for (size_t i = 0; i < p.size (); i++)
  {
    P(i,0) = p[i].X ();
    P(i,1) = p[i].Y ();
    P(i,2) = p[i].Z ();
  }
  return P;
}

// The colour the document D gives the solid S, its own or, failing that,
// that of its first face with one; false when it has none
static bool
colourof (const xdedoc& d, const TopoDS_Shape& s, Quantity_Color& c)
{
  const Handle (XCAFDoc_ColorTool) ct = d.colours ();
  for (const XCAFDoc_ColorType t : {XCAFDoc_ColorGen, XCAFDoc_ColorSurf})
  {
    if (ct->GetColor (s, t, c))
    {
      return true;
    }
  }
  for (TopExp_Explorer x (s, TopAbs_FACE); x.More (); x.Next ())
  {
    for (const XCAFDoc_ColorType t : {XCAFDoc_ColorGen, XCAFDoc_ColorSurf})
    {
      if (ct->GetColor (x.Current (), t, c))
      {
        return true;
      }
    }
  }
  return false;
}

// The shapes of the STEP file FILE as one shape, in millimetres, and the
// colours of its solids, in the order a map of them gives: a cell of the
// shape's bytes and an N-by-3 matrix of red, green and blue from 0 to 1, a
// row of NaN for a solid without one, or empty when none has one
static Cell
readstep (const string& file, const string& caller)
{
  xdedoc d;
  STEPCAFControl_Reader r;
  r.SetColorMode (Standard_True);
  r.SetNameMode (Standard_True);
  Interface_Static::SetCVal ("xstep.cascade.unit", "MM");
  if (r.ReadFile (file.c_str ()) != IFSelect_RetDone)
  {
    error ("%s: cannot read '%s' as a STEP file.", caller.c_str (),
           file.c_str ());
  }
  if (! r.Transfer (d.doc))
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  TDF_LabelSequence roots;
  d.shapes ()->GetFreeShapes (roots);
  TopoDS_Shape s;
  if (roots.Length () == 1)
  {
    s = XCAFDoc_ShapeTool::GetShape (roots (1));
  }
  else
  {
    TopoDS_Compound c;
    BRep_Builder b;
    b.MakeCompound (c);
    for (int i = 1; i <= roots.Length (); i++)
    {
      b.Add (c, XCAFDoc_ShapeTool::GetShape (roots (i)));
    }
    s = c;
  }
  if (count (s, TopAbs_FACE) == 0)
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes (s, TopAbs_SOLID, solids);
  Matrix C (solids.Extent (), 3, octave_NaN);
  bool any = false;
  for (int i = 1; i <= solids.Extent (); i++)
  {
    Quantity_Color c;
    if (colourof (d, solids (i), c))
    {
      double rgb[3];
      c.Values (rgb[0], rgb[1], rgb[2], Quantity_TOC_sRGB);
      for (int k = 0; k < 3; k++)
      {
        C(i-1,k) = rgb[k];
      }
      any = true;
    }
  }
  Cell out (1, 2);
  out(0) = todata (s);
  out(1) = any ? C : Matrix ();
  return out;
}

// The frame a placement carries a part into, its origin, x axis, y axis
// and normal one after another into F, as displacement gives them
static void
frameof (const TopLoc_Location& loc, double *f, const string& caller)
{
  const gp_Trsf t = loc.Transformation ();
  if (t.IsNegative ())
  {
    error ("%s: the file places a part mirrored, which a model.Assembly "
           "cannot.", caller.c_str ());
  }
  const gp_Pnt o = gp_Pnt (0, 0, 0).Transformed (t);
  const gp_Dir axes[3] = {gp_Dir (1, 0, 0).Transformed (t),
                          gp_Dir (0, 1, 0).Transformed (t),
                          gp_Dir (0, 0, 1).Transformed (t)};
  f[0] = o.X ();
  f[1] = o.Y ();
  f[2] = o.Z ();
  for (int k = 0; k < 3; k++)
  {
    f[3 + 3 * k] = axes[k].X ();
    f[4 + 3 * k] = axes[k].Y ();
    f[5 + 3 * k] = axes[k].Z ();
  }
}

// The assembly of the STEP file FILE, in millimetres, as writeassembly takes
// one: a cell of NAMES, DATA, COLOURS, CHILDREN and INSTANCES, the whole
// last.  A part placed several times is one definition.  Several shapes at
// the top of the file are placed, where they are, in an assembly named
// NAME; a single part is returned as it is.
static Cell
readassembly (const string& file, const string& name, const string& caller)
{
  xdedoc d;
  STEPCAFControl_Reader r;
  r.SetColorMode (Standard_True);
  r.SetNameMode (Standard_True);
  Interface_Static::SetCVal ("xstep.cascade.unit", "MM");
  if (r.ReadFile (file.c_str ()) != IFSelect_RetDone)
  {
    error ("%s: cannot read '%s' as a STEP file.", caller.c_str (),
           file.c_str ());
  }
  if (! r.Transfer (d.doc))
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  vector<octave_value> names, data, colours, children, instances;
  std::map<string, int> seen;
  std::function<int (const TDF_Label&)> visit;
  visit = [&] (const TDF_Label& l) -> int
  {
    TCollection_AsciiString entry;
    TDF_Tool::Entry (l, entry);
    const auto it = seen.find (entry.ToCString ());
    if (it != seen.end ())
    {
      return it->second;
    }
    string nm = labelname (l);
    if (XCAFDoc_ShapeTool::IsAssembly (l))
    {
      TDF_LabelSequence comps;
      XCAFDoc_ShapeTool::GetComponents (l, comps);
      Matrix C (comps.Length (), 13);
      Cell inst (1, comps.Length ());
      for (int k = 1; k <= comps.Length (); k++)
      {
        TDF_Label ref;
        XCAFDoc_ShapeTool::GetReferredShape (comps (k), ref);
        C(k-1,0) = visit (ref) + 1;
        double f[12];
        frameof (XCAFDoc_ShapeTool::GetLocation (comps (k)), f, caller);
        for (int j = 0; j < 12; j++)
        {
          C(k-1,j+1) = f[j];
        }
        const string in = labelname (comps (k));
        inst(k-1) = in.empty () ? labelname (ref) : in;
      }
      names.push_back (nm.empty () ? "assembly" : nm);
      data.push_back (uint8NDArray (dim_vector (0, 0)));
      colours.push_back (Matrix ());
      children.push_back (C);
      instances.push_back (inst);
    }
    else
    {
      const TopoDS_Shape s = XCAFDoc_ShapeTool::GetShape (l);
      const TopTools_IndexedMapOfShape solids = solidsof (s);
      Matrix C (solids.Extent (), 3, octave_NaN);
      bool any = false;
      for (int i = 1; i <= solids.Extent (); i++)
      {
        Quantity_Color c;
        if (colourof (d, solids (i), c))
        {
          double rgb[3];
          c.Values (rgb[0], rgb[1], rgb[2], Quantity_TOC_sRGB);
          for (int k = 0; k < 3; k++)
          {
            C(i-1,k) = rgb[k];
          }
          any = true;
        }
      }
      names.push_back (nm.empty () ? "part" : nm);
      data.push_back (todata (s));
      colours.push_back (any ? C : Matrix ());
      children.push_back (Matrix ());
      instances.push_back (Cell ());
    }
    const int k = names.size () - 1;
    seen[entry.ToCString ()] = k;
    return k;
  };
  TDF_LabelSequence roots;
  d.shapes ()->GetFreeShapes (roots);
  if (roots.Length () == 0)
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  vector<int> top;
  for (int i = 1; i <= roots.Length (); i++)
  {
    top.push_back (visit (roots (i)));
  }
  if (top.size () > 1)
  {
    // The shapes at the top of the file, placed where they are
    Matrix C (top.size (), 13, 0.0);
    Cell inst (1, top.size ());
    for (size_t k = 0; k < top.size (); k++)
    {
      C(k,0) = top[k] + 1;
      C(k,4) = C(k,8) = C(k,12) = 1;
      inst(k) = names[top[k]];
    }
    names.push_back (name);
    data.push_back (uint8NDArray (dim_vector (0, 0)));
    colours.push_back (Matrix ());
    children.push_back (C);
    instances.push_back (inst);
  }
  auto tocell = [] (const vector<octave_value>& v)
  {
    Cell c (1, v.size ());
    for (size_t i = 0; i < v.size (); i++)
    {
      c(i) = v[i];
    }
    return c;
  };
  Cell out (1, 5);
  out(0) = tocell (names);
  out(1) = tocell (data);
  out(2) = tocell (colours);
  out(3) = tocell (children);
  out(4) = tocell (instances);
  return out;
}

DEFUN_DLD (__occt__, args, ,
           "-*- texinfo -*-\n\
 @deftypefn {} {@var{out} =} __occt__ (@var{cmd}, @var{caller}, @dots{})\n\
\n\
\n\
Run one Open CASCADE operation.  \n\
\n\
@var{cmd} names the operation and @var{caller} the function on whose behalf \
it runs, which is the name any error is raised under.  Shapes go in and come \
out as the uint8 bytes held by a @qcode{solid.Shape}.  The arguments are \
validated by the caller and are not checked again. \n\
\n\
This is a helper function for the @qcode{solid} namespace.  Do NOT use this \
function directly. \n\
\n\
@end deftypefn")
{
  // Validate input
  if (args.length () < 2 || ! args(0).is_string () || ! args(1).is_string ())
  {
    error ("__occt__: invalid number of input arguments.");
  }
  const string cmd = args(0).string_value ();
  const string caller = args(1).string_value ();

  quiet ();

  octave_value out;
  try
  {
    // Primitives
    if (cmd == "box")
    {
      out = todata (BRepPrimAPI_MakeBox (args(2).double_value (),
                                         args(3).double_value (),
                                         args(4).double_value ()).Shape ());
    }
    else if (cmd == "cylinder")
    {
      out = todata (BRepPrimAPI_MakeCylinder (args(2).double_value (),
                                              args(3).double_value ())
                    .Shape ());
    }
    // A wedge: a block DX by DY at the base, DZ high, its top face spanning
    // XMIN to XMAX and YMIN to YMAX.  Open CASCADE builds a wedge with its
    // height along y, so it is built in axes that turn that onto z.
    else if (cmd == "wedge")
    {
      const double dx = args(2).double_value ();
      const double dy = args(3).double_value ();
      const double dz = args(4).double_value ();
      const NDArray top = args(5).array_value ();
      const gp_Ax2 axes (gp_Pnt (0, dy, 0), gp_Dir (0, -1, 0),
                         gp_Dir (1, 0, 0));
      out = todata (BRepPrimAPI_MakeWedge (axes, dx, dz, dy, top(0),
                                           dy - top(3), top(2), dy - top(1))
                    .Shape ());
    }
    else if (cmd == "cone")
    {
      out = todata (BRepPrimAPI_MakeCone (args(2).double_value (),
                                          args(3).double_value (),
                                          args(4).double_value ()).Shape ());
    }
    else if (cmd == "sphere")
    {
      out = todata (BRepPrimAPI_MakeSphere (args(2).double_value ()).Shape ());
    }
    else if (cmd == "torus")
    {
      out = todata (BRepPrimAPI_MakeTorus (args(2).double_value (),
                                           args(3).double_value ()).Shape ());
    }
    // A primitive put in a UCS: its own axes laid on the frame's, whose rows
    // are the origin, x axis, y axis and normal
    else if (cmd == "polyhedron")
    {
      out = todata (polyhedron (args(2).matrix_value (),
                                args(3).matrix_value (),
                                args(4).bool_value (), caller));
    }
    else if (cmd == "surface")
    {
      out = todata (gridsurface (args(2).matrix_value (),
                                 args(3).matrix_value (),
                                 args(4).matrix_value (),
                                 args(5).double_value (),
                                 args(6).double_value (), caller));
    }
    else if (cmd == "place")
    {
      const Matrix f = args(3).matrix_value ();
      gp_Trsf t;
      t.SetDisplacement (gp_Ax3 (gp::XOY ()),
                         gp_Ax3 (gp_Pnt (f(0,0), f(0,1), f(0,2)),
                                 gp_Dir (f(3,0), f(3,1), f(3,2)),
                                 gp_Dir (f(1,0), f(1,1), f(1,2))));
      out = todata (transform (toshape (args(2), caller), t));
    }

    // Solids from regions, each made where the region's plane puts it.  An
    // extrusion rises along the normal; a revolution turns about the plane's
    // y axis through its origin; a loft passes through regions where they
    // lie; a sweep carries the region from where it lies along a path.
    // An extrusion runs H1 along the normal and H2 against it, each side's
    // walls leaning in by its own angle
    else if (cmd == "extrude")
    {
      const region r = toregion (args(2));
      const double h1 = args(3).double_value ();
      const double h2 = args(4).double_value ();
      const double a1 = args(5).double_value () * M_PI / 180;
      const double a2 = args(6).double_value () * M_PI / 180;
      if (a1 == 0 && a2 == 0)
      {
        gp_Trsf t;
        t.SetTranslation (gp_Vec (r.normal) * -h2);
        out = todata (BRepPrimAPI_MakePrism
                        (transform (planarface (r), t),
                         gp_Vec (r.normal) * (h1 + h2)).Shape ());
      }
      else
      {
        TopTools_ListOfShape sides;
        if (h1 > 0)
        {
          sides.Append (taperedside (r, h1, a1, caller));
        }
        if (h2 > 0)
        {
          // The far side is a near side mirrored in the region's plane
          gp_Trsf m;
          m.SetMirror (gp_Ax2 (r.origin, r.normal));
          sides.Append (transform (taperedside (r, h2, a2, caller), m));
        }
        if (sides.Extent () == 1)
        {
          out = todata (sides.First ());
        }
        else
        {
          TopTools_ListOfShape objects, tools;
          objects.Append (sides.First ());
          tools.Append (sides.Last ());
          BRepAlgoAPI_Fuse op;
          op.SetArguments (objects);
          op.SetTools (tools);
          out = todata (boolean (op, caller, "extrusion"));
        }
      }
    }
    else if (cmd == "revolve")
    {
      const region r = toregion (args(2));
      const gp_Ax1 axis (r.origin, r.y);
      const double angle = args(3).double_value ();
      if (angle >= 360)
      {
        out = todata (BRepPrimAPI_MakeRevol (planarface (r), axis).Shape ());
      }
      else
      {
        out = todata (BRepPrimAPI_MakeRevol (planarface (r), axis,
                                             angle * M_PI / 180).Shape ());
      }
    }
    else if (cmd == "loft")
    {
      const Cell R = args(2).cell_value ();
      const bool ruled = args(3).bool_value ();
      vector<region> rs;
      for (octave_idx_type i = 0; i < R.numel (); i++)
      {
        rs.push_back (toregion (R(i)));
      }
      // The outlines lofted, less each hole lofted through its sections
      auto loft = [&] (std::function<TopoDS_Wire (const region&)> pick)
      {
        BRepOffsetAPI_ThruSections op (Standard_True, ruled);
        for (const region& r : rs)
        {
          op.AddWire (pick (r));
        }
        op.Build ();
        if (! op.IsDone ())
        {
          error ("%s: Open CASCADE could not compute the loft.",
                 caller.c_str ());
        }
        return op.Shape ();
      };
      const TopoDS_Shape outer = loft ([] (const region& r)
                                       { return r.outer; });
      vector<TopoDS_Shape> holes;
      for (size_t k = 0; k < rs[0].holes.size (); k++)
      {
        holes.push_back (loft ([k] (const region& r)
                               { return r.holes[k]; }));
      }
      out = todata (cutall (outer, holes, caller));
    }
    else if (cmd == "sweep")
    {
      const region r = toregion (args(2));
      const TopoDS_Wire spine = chain (args(3));
      vector<TopoDS_Shape> holes;
      for (const TopoDS_Wire& h : r.holes)
      {
        holes.push_back (pipe (spine, h, false, caller));
      }
      out = todata (cutall (pipe (spine, r.outer, false, caller), holes,
                            caller));
    }

    // A helix turns a region about its plane's y axis while it rises along
    // it by the pitch on every turn.  The spine is an exact helix on a
    // cylinder of the given radius, made about the z axis and carried onto
    // the region's frame, and the Frenet frame keeps the region in the plane
    // through the axis, as a thread's profile is.
    else if (cmd == "helix")
    {
      const region r = toregion (args(2));
      const double pitch = args(3).double_value ();
      const double turns = args(4).double_value ();
      const double rad = args(5).double_value ();
      const gp_Dir2d d (2 * M_PI, pitch);
      const double len = turns * hypot (2 * M_PI, pitch);
      Handle (Geom_CylindricalSurface) cyl
        = new Geom_CylindricalSurface (gp_Ax3 (gp::XOY ()), rad);
      Handle (Geom2d_Line) line = new Geom2d_Line (gp_Pnt2d (0, 0), d);
      TopoDS_Edge e = BRepBuilderAPI_MakeEdge (line, cyl, 0, len).Edge ();
      BRepLib::BuildCurves3d (e);
      gp_Trsf place;
      place.SetDisplacement (gp_Ax3 (gp::XOY ()),
                             gp_Ax3 (r.origin, r.y, r.x));
      const TopoDS_Wire spine = TopoDS::Wire (transform
                                  (BRepBuilderAPI_MakeWire (e).Wire (), place));
      vector<TopoDS_Shape> holes;
      for (const TopoDS_Wire& h : r.holes)
      {
        holes.push_back (pipe (spine, h, true, caller));
      }
      out = todata (cutall (pipe (spine, r.outer, true, caller), holes,
                            caller));
    }

    // Features on chosen edges and faces
    else if (cmd == "fillet" || cmd == "chamfer")
    {
      const TopoDS_Shape s = toshape (args(2), caller);
      const TopTools_ListOfShape edges
        = picked (s, TopAbs_EDGE, args(3).array_value ());
      const double size = args(4).array_value ()(0);
      TopoDS_Shape r;
      origins L;
      if (cmd == "fillet")
      {
        BRepFilletAPI_MakeFillet op (s);
        for (const TopoDS_Shape& e : edges)
        {
          op.Add (size, TopoDS::Edge (e));
        }
        op.Build ();
        if (! op.IsDone () || ! BRepCheck_Analyzer (op.Shape ()).IsValid ())
        {
          error ("%s: Open CASCADE could not round the edges.",
                 caller.c_str ());
        }
        r = op.Shape ();
        L = lineage (op, {s}, r);
      }
      else
      {
        BRepFilletAPI_MakeChamfer op (s);
        const NDArray d = args(4).array_value ();
        if (args.length () > 6 && args(6).double_value () > 0)
        {
          // D is set back along the face given, and the chamfer meets that
          // face at the angle given
          TopTools_IndexedMapOfShape fmap;
          TopExp::MapShapes (s, TopAbs_FACE, fmap);
          const TopoDS_Face f = TopoDS::Face
                                  (fmap (static_cast<int> (args(5)
                                                           .double_value ())));
          const double a = args(6).double_value () * M_PI / 180;
          for (const TopoDS_Shape& e : edges)
          {
            op.AddDA (d(0), a, TopoDS::Edge (e), f);
          }
        }
        else if (d.numel () == 2)
        {
          // D1 is set back along the face given, D2 along the other
          TopTools_IndexedMapOfShape fmap;
          TopExp::MapShapes (s, TopAbs_FACE, fmap);
          const TopoDS_Face f = TopoDS::Face
                                  (fmap (static_cast<int> (args(5)
                                                           .double_value ())));
          for (const TopoDS_Shape& e : edges)
          {
            op.Add (d(0), d(1), TopoDS::Edge (e), f);
          }
        }
        else
        {
          for (const TopoDS_Shape& e : edges)
          {
            op.Add (size, TopoDS::Edge (e));
          }
        }
        op.Build ();
        if (! op.IsDone () || ! BRepCheck_Analyzer (op.Shape ()).IsValid ())
        {
          error ("%s: Open CASCADE could not chamfer the edges.",
                 caller.c_str ());
        }
        r = op.Shape ();
        L = lineage (op, {s}, r);
      }
      out = traced (r, L);
    }
    else if (cmd == "shell")
    {
      const TopoDS_Shape s = toshape (args(2), caller);
      const TopTools_ListOfShape open
        = picked (s, TopAbs_FACE, args(3).array_value ());
      // The walls grow inwards, or outwards when asked, each the default
      // thickness unless given one of its own
      const bool outward = (args.length () > 5 && args(5).bool_value ());
      const double sign = outward ? 1 : -1;
      const double t = args(4).double_value ();
      BRepOffset_MakeOffset op;
      op.Initialize (s, sign * t, 1e-6, BRepOffset_Skin, Standard_False,
                     Standard_False, GeomAbs_Intersection);
      for (const TopoDS_Shape& f : open)
      {
        op.AddFace (TopoDS::Face (f));
      }
      if (args.length () > 7)
      {
        const NDArray fi = args(6).array_value ();
        const NDArray ft = args(7).array_value ();
        const TopTools_ListOfShape thick = picked (s, TopAbs_FACE, fi);
        octave_idx_type k = 0;
        for (const TopoDS_Shape& f : thick)
        {
          op.SetOffsetOnFace (TopoDS::Face (f), sign * ft(k++));
        }
      }
      op.MakeThickSolid ();
      TopoDS_Shape r;
      if (op.IsDone ())
      {
        r = op.Shape ();
        // With no face opened Open CASCADE returns the offset solid: inwards
        // the cavity, cut from the shape; outwards the outside, from which
        // the shape is cut
        if (open.IsEmpty ())
        {
          // The outside comes back inside out, its volume negative
          GProp_GProps g;
          BRepGProp::VolumeProperties (r, g);
          if (g.Mass () < 0)
          {
            r.Reverse ();
          }
          BRepAlgoAPI_Cut cut;
          TopTools_ListOfShape objects, tools;
          objects.Append (outward ? r : s);
          tools.Append (outward ? s : r);
          cut.SetArguments (objects);
          cut.SetTools (tools);
          cut.Build ();
          r = (cut.HasErrors () || ! cut.IsDone ()) ? TopoDS_Shape ()
                                                    : cut.Shape ();
        }
      }
      // Walls too thick for the shape can leave it untouched rather than
      // fail, so a result no smaller than the shape is a failure too
      GProp_GProps before, after;
      BRepGProp::VolumeProperties (s, before);
      if (! r.IsNull ())
      {
        BRepGProp::VolumeProperties (r, after);
      }
      const bool same = std::abs (after.Mass () - before.Mass ())
                        <= 1e-9 * before.Mass ();
      if (r.IsNull () || ! BRepCheck_Analyzer (r).IsValid ()
          || after.Mass () <= 0 || same
          || (! outward && after.Mass () > before.Mass ()))
      {
        error ("%s: Open CASCADE could not hollow the shape.",
               caller.c_str ());
      }
      out = traced (r, overlap (s, r));
    }

    // Booleans.  A union and a difference take every shape after the first
    // as a tool in one operation, which is several times faster than taking
    // them one at a time.  An intersection cannot: Open CASCADE intersects
    // the first shape with the union of the tools, so it goes pairwise.
    else if (cmd == "fuse" || cmd == "cut")
    {
      TopTools_ListOfShape objects, tools;
      vector<TopoDS_Shape> sources;
      for (int i = 2; i < args.length (); i++)
      {
        sources.push_back (toshape (args(i), caller));
        (i == 2 ? objects : tools).Append (sources.back ());
      }
      if (cmd == "fuse")
      {
        BRepAlgoAPI_Fuse op;
        op.SetArguments (objects);
        op.SetTools (tools);
        const TopoDS_Shape r = boolean (op, caller, "union");
        out = traced (r, lineage (op, sources, r));
      }
      else
      {
        BRepAlgoAPI_Cut op;
        op.SetArguments (objects);
        op.SetTools (tools);
        const TopoDS_Shape r = boolean (op, caller, "difference");
        out = traced (r, lineage (op, sources, r));
      }
    }
    else if (cmd == "common")
    {
      // Pairwise, each step's lineage carried back to the operands' solids,
      // numbered all in turn: SEEN of them before the shape intersected next
      TopoDS_Shape s = toshape (args(2), caller);
      origins L = itself (count (s, TopAbs_SOLID));
      int seen = L.size ();
      for (int i = 3; i < args.length () && count (s, TopAbs_FACE) > 0; i++)
      {
        const TopoDS_Shape t = toshape (args(i), caller);
        TopTools_ListOfShape objects, tools;
        objects.Append (s);
        tools.Append (t);
        BRepAlgoAPI_Common op;
        op.SetArguments (objects);
        op.SetTools (tools);
        const TopoDS_Shape r = boolean (op, caller, "intersection");
        const origins step = lineage (op, {s, t}, r);
        const int ns = count (s, TopAbs_SOLID);
        origins next (step.size ());
        for (size_t j = 0; j < step.size (); j++)
        {
          for (int k : step[j])
          {
            if (k <= ns)
            {
              next[j].insert (L[k-1].begin (), L[k-1].end ());
            }
            else
            {
              next[j].insert (seen + k - ns);
            }
          }
        }
        seen += count (t, TopAbs_SOLID);
        L = next;
        s = r;
      }
      out = traced (s, L);
    }

    // Transformations
    else if (cmd == "translate")
    {
      const gp_Pnt v = topoint (args(3));
      gp_Trsf t;
      t.SetTranslation (gp_Vec (v.X (), v.Y (), v.Z ()));
      out = todata (transform (toshape (args(2), caller), t));
    }
    else if (cmd == "rotate")
    {
      gp_Trsf t;
      t.SetRotation (gp_Ax1 (topoint (args(5)), todir (args(4))),
                     args(3).double_value () * M_PI / 180);
      out = todata (transform (toshape (args(2), caller), t));
    }
    else if (cmd == "mirror")
    {
      gp_Trsf t;
      t.SetMirror (gp_Ax2 (topoint (args(4)), todir (args(3))));
      out = todata (transform (toshape (args(2), caller), t));
    }
    else if (cmd == "scale")
    {
      gp_Trsf t;
      t.SetScale (topoint (args(4)), args(3).double_value ());
      out = todata (transform (toshape (args(2), caller), t));
    }

    // A scaling by its own factor along each axis, about a point: the curved
    // faces become B-spline surfaces, as a stretched circle is no longer a
    // circle, and the flat ones are made planes again
    else if (cmd == "gscale")
    {
      const RowVector f = args(3).row_vector_value ();
      const gp_Pnt p = topoint (args(4));
      gp_GTrsf g;
      g.SetVectorialPart (gp_Mat (f(0), 0, 0, 0, f(1), 0, 0, 0, f(2)));
      g.SetTranslationPart (gp_XYZ (p.X () * (1 - f(0)), p.Y () * (1 - f(1)),
                                    p.Z () * (1 - f(2))));
      BRepBuilderAPI_GTransform gt (toshape (args(2), caller), g,
                                    Standard_True);
      if (! gt.IsDone ())
      {
        error ("%s: Open CASCADE could not scale the shape.",
               caller.c_str ());
      }
      out = todata (planarize (gt.Shape ()));
    }

    // Shapes together in one, as they are, none fused with another
    else if (cmd == "compound")
    {
      BRep_Builder bb;
      TopoDS_Compound c;
      bb.MakeCompound (c);
      for (int i = 2; i < args.length (); i++)
      {
        const TopoDS_Shape t = toshape (args(i), caller);
        if (t.ShapeType () != TopAbs_COMPOUND)
        {
          bb.Add (c, t);
          continue;
        }
        for (TopoDS_Iterator it (t); it.More (); it.Next ())
        {
          bb.Add (c, it.Value ());
        }
      }
      out = traced (c, itself (count (c, TopAbs_SOLID)));
    }

    // The cut through a shape by the plane of a frame, rows origin, x axis,
    // y axis and normal: the shape is carried into the frame, where the plane
    // is z = 0, and what it has in common with a face of that plane larger
    // than the shape is the cut, a face lying in the plane included.  Each
    // face of it comes back as its outer loop and its inner loops.
    else if (cmd == "section")
    {
      const Matrix f = args(3).matrix_value ();
      gp_Trsf t;
      t.SetTransformation (gp_Ax3 (gp_Pnt (f(0,0), f(0,1), f(0,2)),
                                   gp_Dir (f(3,0), f(3,1), f(3,2)),
                                   gp_Dir (f(1,0), f(1,1), f(1,2))));
      const TopoDS_Shape s = transform (toshape (args(2), caller), t);
      Bnd_Box box;
      BRepBndLib::Add (s, box);
      double x0, y0, z0, x1, y1, z1;
      box.Get (x0, y0, z0, x1, y1, z1);
      const double tol = box.GetGap () + Precision::Confusion ();
      if (z0 <= tol && z1 >= -tol)
      {
        const double r = 1 + (x1 - x0) + (y1 - y0);
        const TopoDS_Face plane
          = BRepBuilderAPI_MakeFace (gp_Pln (gp::XOY ()), x0 - r, x1 + r,
                                     y0 - r, y1 + r).Face ();
        BRepAlgoAPI_Common op (s, plane);
        const TopoDS_Shape c = boolean (op, caller, "section");
        out = facesout (c, (x1 - x0) * (y1 - y0) + 1);
      }
      else
      {
        out = Cell (1, 0);
      }
    }

    // The outline of a shape seen along the normal of a frame, rows origin,
    // x axis, y axis and normal, on the plane of the frame: the shape is
    // carried into the frame, its edges and outlines drawn on the plane
    // z = 0, and a face of that plane larger than the shape split by them.
    // A piece is kept where a line along z through a point inside it meets
    // the shape; the pieces kept are made one, the edges between them gone.
    // Each face of it comes back as its outer loop and its inner loops.
    else if (cmd == "projection")
    {
      const Matrix f = args(3).matrix_value ();
      gp_Trsf t;
      t.SetTransformation (gp_Ax3 (gp_Pnt (f(0,0), f(0,1), f(0,2)),
                                   gp_Dir (f(3,0), f(3,1), f(3,2)),
                                   gp_Dir (f(1,0), f(1,1), f(1,2))));
      const TopoDS_Shape s = transform (toshape (args(2), caller), t);
      out = projection (s, caller);
    }

    // The faces of a flat shape, such as the outlines of text, read in the
    // frame given as the faces of a section are.  Filled as a font is when
    // asked: a face for every loop, those running as the largest does
    // united and the others cut out, so that loops that cross or overlap,
    // as the strokes of a bold letter may, make clean faces.
    else if (cmd == "faces2d")
    {
      TopoDS_Shape c = transform (toshape (args(2), caller),
                                  intoframe (args(3).matrix_value ()));
      if (args.length () > 4 && args(4).bool_value ())
      {
        vector<TopoDS_Wire> W;
        vector<double> A;
        double big = 0;
        for (TopExp_Explorer x (c, TopAbs_WIRE); x.More (); x.Next ())
        {
          W.push_back (TopoDS::Wire (x.Current ()));
          A.push_back (wirearea (W.back ()));
          if (std::abs (A.back ()) > std::abs (big))
          {
            big = A.back ();
          }
        }
        TopTools_ListOfShape pos, neg;
        for (size_t i = 0; i < W.size (); i++)
        {
          const bool fill = (A[i] > 0) == (big > 0);
          const TopoDS_Wire w = (A[i] > 0) ? W[i]
                                           : TopoDS::Wire (W[i].Reversed ());
          BRepBuilderAPI_MakeFace mf (w, Standard_True);
          if (mf.IsDone ())
          {
            (fill ? pos : neg).Append (mf.Face ());
          }
        }
        if (pos.IsEmpty ())
        {
          c = TopoDS_Shape ();
        }
        else
        {
          TopoDS_Shape u = pos.First ();
          if (pos.Extent () > 1)
          {
            TopTools_ListOfShape first, rest = pos;
            first.Append (rest.First ());
            rest.RemoveFirst ();
            BRepAlgoAPI_Fuse b;
            b.SetArguments (first);
            b.SetTools (rest);
            u = boolean (b, caller, "text");
          }
          if (! neg.IsEmpty ())
          {
            TopTools_ListOfShape first;
            first.Append (u);
            BRepAlgoAPI_Cut b;
            b.SetArguments (first);
            b.SetTools (neg);
            u = boolean (b, caller, "text");
          }
          c = u;
        }
      }
      Bnd_Box box;
      BRepBndLib::Add (c, box);
      double x0 = 0, y0 = 0, z0, x1 = 0, y1 = 0, z1;
      if (! box.IsVoid ())
      {
        box.Get (x0, y0, z0, x1, y1, z1);
      }
      out = facesout (c, (x1 - x0) * (y1 - y0) + 1);
    }

    // Regions combined: the union, difference or intersection of regions
    // in one plane, read back in the frame of the first as the faces of a
    // section are
    else if (cmd == "region2d")
    {
      const string op = args(2).string_value ();
      const Cell R = args(3).cell_value ();
      vector<TopoDS_Shape> f;
      for (octave_idx_type i = 0; i < R.numel (); i++)
      {
        f.push_back (planarface (toregion (R(i))));
      }
      TopoDS_Shape c = f[0];
      if (f.size () > 1)
      {
        TopTools_ListOfShape first, rest;
        first.Append (f[0]);
        for (size_t i = 1; i < f.size (); i++)
        {
          rest.Append (f[i]);
        }
        if (op == "union")
        {
          BRepAlgoAPI_Fuse b;
          b.SetArguments (first);
          b.SetTools (rest);
          c = boolean (b, caller, "union");
        }
        else if (op == "subtract")
        {
          BRepAlgoAPI_Cut b;
          b.SetArguments (first);
          b.SetTools (rest);
          c = boolean (b, caller, "difference");
        }
        else
        {
          for (size_t i = 1; i < f.size (); i++)
          {
            BRepAlgoAPI_Common b (c, f[i]);
            c = boolean (b, caller, "intersection");
          }
        }
      }
      const Matrix fr = args(4).matrix_value ();
      c = transform (c, intoframe (fr));
      Bnd_Box box;
      BRepBndLib::Add (c, box);
      double x0 = 0, y0 = 0, z0, x1 = 0, y1 = 0, z1;
      if (! box.IsVoid ())
      {
        box.Get (x0, y0, z0, x1, y1, z1);
      }
      out = facesout (c, (x1 - x0) * (y1 - y0) + 1);
    }

    // A region offset in its plane by D, outwards where D is positive, its
    // corners round, sharp, or cut square to the corner at the distance D:
    // the offset of its face, whose loops running the way the outline runs
    // are filled and those running the other way cut out
    else if (cmd == "offset2d")
    {
      // Worked in the region's frame, where its plane is z = 0
      const Matrix fr = args(5).matrix_value ();
      const TopoDS_Face face
        = TopoDS::Face (transform (planarface (toregion (args(2))),
                                   intoframe (fr)));
      const double d = args(3).double_value ();
      const int corners = args(4).int_value ();
      // A chamfer is cut from the round corners
      BRepOffsetAPI_MakeOffset op (face, corners == 1 ? GeomAbs_Intersection
                                                      : GeomAbs_Arc);
      op.Perform (d);
      if (! op.IsDone ())
      {
        error ("%s: Open CASCADE could not compute the offset.",
               caller.c_str ());
      }
      vector<TopoDS_Face> pos, neg;
      for (TopExp_Explorer x (op.Shape (), TopAbs_WIRE); x.More (); x.Next ())
      {
        TopoDS_Wire w = TopoDS::Wire (x.Current ());
        if (corners == 2)
        {
          w = chamferwire (w, face, std::abs (d));
        }
        // A loop running as the outline does is filled, one running the
        // other way, as a hole does, is cut out
        const bool fill = wirearea (w) > 0;
        BRepBuilderAPI_MakeFace mf (fill ? w : TopoDS::Wire (w.Reversed ()),
                                    Standard_True);
        if (mf.IsDone ())
        {
          (fill ? pos : neg).push_back (mf.Face ());
        }
      }
      TopoDS_Shape c;
      if (! pos.empty ())
      {
        c = pos[0];
        if (pos.size () > 1)
        {
          TopTools_ListOfShape first, rest;
          first.Append (pos[0]);
          for (size_t i = 1; i < pos.size (); i++)
          {
            rest.Append (pos[i]);
          }
          BRepAlgoAPI_Fuse b;
          b.SetArguments (first);
          b.SetTools (rest);
          c = boolean (b, caller, "offset");
        }
        if (! neg.empty ())
        {
          TopTools_ListOfShape first, rest;
          first.Append (c);
          for (const TopoDS_Face& g : neg)
          {
            rest.Append (g);
          }
          BRepAlgoAPI_Cut b;
          b.SetArguments (first);
          b.SetTools (rest);
          c = boolean (b, caller, "offset");
        }
        Bnd_Box box;
        BRepBndLib::Add (c, box);
        double x0, y0, z0, x1, y1, z1;
        box.Get (x0, y0, z0, x1, y1, z1);
        out = facesout (c, (x1 - x0) * (y1 - y0) + 1);
      }
      else
      {
        out = Cell (1, 0);
      }
    }

    // Queries
    else if (cmd == "volume")
    {
      out = volumeprops (toshape (args(2), caller)).Mass ();
    }
    else if (cmd == "area")
    {
      out = area (toshape (args(2), caller));
    }
    else if (cmd == "centroid")
    {
      const GProp_GProps p = volumeprops (toshape (args(2), caller));
      RowVector c (3, octave_NaN);
      if (p.Mass () > 0)
      {
        const gp_Pnt g = p.CentreOfMass ();
        c(0) = g.X ();
        c(1) = g.Y ();
        c(2) = g.Z ();
      }
      out = c;
    }
    else if (cmd == "bbox")
    {
      Bnd_Box b;
      BRepBndLib::AddOptimal (toshape (args(2), caller), b, Standard_False,
                              Standard_False);
      double x0, y0, z0, x1, y1, z1;
      b.Get (x0, y0, z0, x1, y1, z1);
      RowVector r (6);
      r(0) = x0;
      r(1) = y0;
      r(2) = z0;
      r(3) = x1;
      r(4) = y1;
      r(5) = z1;
      out = r;
    }
    else if (cmd == "edges")
    {
      out = edgeinfo (toshape (args(2), caller));
    }
    else if (cmd == "faces")
    {
      out = faceinfo (toshape (args(2), caller));
    }
    // Closed loops in a plane checked as a region's loops are: see loopcheck
    else if (cmd == "loopcheck")
    {
      out = loopcheck (args(2).cell_value (), args(3).matrix_value ());
    }
    else if (cmd == "valid")
    {
      out = BRepCheck_Analyzer (toshape (args(2), caller)).IsValid ()
            ? true : false;
    }
    else if (cmd == "count")
    {
      const string what = args(3).string_value ();
      TopAbs_ShapeEnum type = TopAbs_SOLID;
      if (what == "face")
      {
        type = TopAbs_FACE;
      }
      else if (what == "edge")
      {
        type = TopAbs_EDGE;
      }
      else if (what == "vertex")
      {
        type = TopAbs_VERTEX;
      }
      out = static_cast<double> (count (toshape (args(2), caller), type));
    }

    // Files
    else if (cmd == "writestep")
    {
      writestep (toshape (args(2), caller), args(3).string_value (),
                 args(4).string_value (), args(5).matrix_value (), caller);
    }
    else if (cmd == "tessellate")
    {
      out = tessellation (toshape (args(2), caller), args(3).double_value (),
                          args(4).double_value () * M_PI / 180, caller);
    }
    else if (cmd == "points")
    {
      out = surfacepoints (toshape (args(2), caller), args(3).double_value (),
                           args(4).double_value () * M_PI / 180, caller);
    }
    else if (cmd == "writeassembly")
    {
      writeassembly (args(2).string_value (), args(3).cell_value (),
                     args(4).cell_value (), args(5).cell_value (),
                     args(6).cell_value (), args(7).cell_value (), caller);
    }
    else if (cmd == "readassembly")
    {
      out = readassembly (args(2).string_value (), args(3).string_value (),
                          caller);
    }
    else if (cmd == "readstep")
    {
      out = readstep (args(2).string_value (), caller);
    }
    else
    {
      error ("__occt__: unknown command '%s'.", cmd.c_str ());
    }
  }
  catch (const Standard_Failure& e)
  {
    const char *msg = e.GetMessageString ();
    if (msg != nullptr && *msg != '\0')
    {
      error ("%s: Open CASCADE failed: %s (%s).", caller.c_str (), msg,
             e.DynamicType ()->Name ());
    }
    error ("%s: Open CASCADE failed (%s).", caller.c_str (),
           e.DynamicType ()->Name ());
  }

  return ovl (out);
}

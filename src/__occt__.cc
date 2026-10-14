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
#include <NCollection_DataMap.hxx>
#include <Quantity_Color.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFApp_Application.hxx>
#include <TDocStd_Document.hxx>
#include <NCollection_Sequence.hxx>
#include <TDF_Label.hxx>
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
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
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
#include <BRepBuilderAPI_MakeSolid.hxx>
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
#include <NCollection_Array2.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <Standard_Version.hxx>
#if OCC_VERSION_MAJOR >= 8
#include <GC_MakeArcOfCircle2d.hxx>
#include <GC_MakeSegment2d.hxx>
#else
#include <GCE2d_MakeArcOfCircle.hxx>
#include <GCE2d_MakeSegment.hxx>
#endif
#if OCC_VERSION_MAJOR >= 8
#include <NCollection_HArray1.hxx>
#else
#include <TColStd_HArray1OfReal.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#endif
#include <GeomAPI.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <Bnd_Box2d.hxx>
#include <IntRes2d_IntersectionSegment.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Pln.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <gp_Cylinder.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TopoDS_Vertex.hxx>
#include <Geom_Plane.hxx>
#include <GProp_GProps.hxx>
#include <Interface_Static.hxx>
#include <NCollection_Array1.hxx>
#include <gp_Pnt.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <Poly_Triangulation.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <StepShape_ManifoldSolidBrep.hxx>
#include <Transfer_TransientProcess.hxx>
#include <TransferBRep.hxx>
#include <XSControl_TransferReader.hxx>
#include <XSControl_WorkSession.hxx>
#include <Standard_Failure.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_List.hxx>
#include <NCollection_IndexedMap.hxx>
#include <TopTools_ShapeMapHasher.hxx>
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

#include "shapebytes.h"

using namespace std;

// The message and the type of an Open CASCADE exception, which 8.0 made a
// std::exception
static const char *
failure (const Standard_Failure& e)
{
#if OCC_VERSION_MAJOR >= 8
  return e.what ();
#else
  return e.GetMessageString ();
#endif
}

static const char *
failurekind (const Standard_Failure& e)
{
#if OCC_VERSION_MAJOR >= 8
  return e.ExceptionType ();
#else
  return e.DynamicType ()->Name ();
#endif
}

// The makers of 2-D segments and arcs, which Open CASCADE 8.0 renamed
#if OCC_VERSION_MAJOR >= 8
using MakeSegment2d = GC_MakeSegment2d;
using MakeArcOfCircle2d = GC_MakeArcOfCircle2d;
#else
using MakeSegment2d = GCE2d_MakeSegment;
using MakeArcOfCircle2d = GCE2d_MakeArcOfCircle;
#endif

// The collections of shapes, named here since Open CASCADE 8.0 deprecates
// the names it gave them
using ShapeList = NCollection_List<TopoDS_Shape>;
using ShapeMap = NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>;
using ShapeListMap = NCollection_IndexedDataMap<TopoDS_Shape, ShapeList,
                                                TopTools_ShapeMapHasher>;

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
  ShapeMap map;
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
  if (! unsealshape (bytes))
  {
    error ("%s: shape data is damaged, or was not made by this version of"
           " the package.", caller.c_str ());
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
  BinTools::Write (s, os, false, false,
                   BinTools_FormatVersion_CURRENT);
  string bytes = os.str ();
  sealshape (bytes);
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
  NCollection_Array1<gp_Pnt> poles (1, p.rows ());
  NCollection_Array1<double> weights (1, p.rows ());
  for (octave_idx_type i = 0; i < p.rows (); i++)
  {
    poles.SetValue (i + 1, gp_Pnt (p(i,0), p(i,1), p(i,2)));
    weights.SetValue (i + 1, w(i));
  }
  NCollection_Array1<double> knots (1, t.numel ());
  NCollection_Array1<int> mults (1, t.numel ());
  for (octave_idx_type i = 0; i < t.numel (); i++)
  {
    knots.SetValue (i + 1, t(i));
    mults.SetValue (i + 1, static_cast<int> (m(i)));
  }
  return new Geom_BSplineCurve (poles, weights, knots, mults, degree);
}

// Whether the arc from A through M to B bows less than a millionth of its
// chord, and so is built as the straight segment it is in effect: Open
// CASCADE puts such an arc on a circle so large that its ends stray
static bool
nearlystraight (const gp_Pnt& a, const gp_Pnt& m, const gp_Pnt& b)
{
  const gp_Vec ab (a, b);
  const double L = ab.Magnitude ();
  return L > 0 && gp_Vec (a, m).Crossed (ab).Magnitude () <= 1e-6 * L * L;
}

static bool
nearlystraight (const gp_Pnt2d& a, const gp_Pnt2d& m, const gp_Pnt2d& b)
{
  const gp_Vec2d ab (a, b);
  const double L = ab.Magnitude ();
  return L > 0 && std::abs (gp_Vec2d (a, m).Crossed (ab)) <= 1e-6 * L * L;
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
    else if (nearlystraight (a, gp_Pnt (m(i,0), m(i,1), m(i,2)), b))
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
  BRepBuilderAPI_MakeFace f (r.outer, true);
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
      NCollection_Array1<gp_Pnt2d> poles (1, pl.rows ());
      NCollection_Array1<double> weights (1, pl.rows ());
      for (octave_idx_type k = 0; k < pl.rows (); k++)
      {
        poles.SetValue (k + 1, inplane (pl, k, f));
        weights.SetValue (k + 1, w(k));
      }
      NCollection_Array1<double> knots (1, t.numel ());
      NCollection_Array1<int> mults (1, t.numel ());
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
    else if (octave::math::isnan (m(i,0))
             || nearlystraight (a, inplane (m, i, f), b))
    {
      c.push_back (MakeSegment2d (a, b).Value ());
    }
    else
    {
      c.push_back (MakeArcOfCircle2d (a, inplane (m, i, f), b).Value ());
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
                                         true).Face ();
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
static ShapeList
picked (const TopoDS_Shape& s, TopAbs_ShapeEnum type, const NDArray& idx)
{
  ShapeMap map;
  TopExp::MapShapes (s, type, map);
  ShapeList list;
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
  BRepBndLib::AddOptimal (s, b, false, false);
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
  ShapeMap map;
  TopExp::MapShapes (s, TopAbs_EDGE, map);
  ShapeListMap faces;
  TopExp::MapShapesAndAncestors (s, TopAbs_EDGE, TopAbs_FACE, faces);
  ShapeMap fmap;
  TopExp::MapShapes (s, TopAbs_FACE, fmap);
  const octave_idx_type n = map.Extent ();
  Cell type (n, 1);
  Cell onfaces (n, 1);
  Matrix dir (n, 3, octave_NaN);
  Matrix box (n, 6);
  boolNDArray seam (dim_vector (n, 1), false);
  for (octave_idx_type i = 0; i < n; i++)
  {
    const TopoDS_Edge e = TopoDS::Edge (map.FindKey (static_cast<int> (i + 1)));
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
  ShapeMap map;
  TopExp::MapShapes (s, TopAbs_FACE, map);
  const octave_idx_type n = map.Extent ();
  Cell type (n, 1);
  Matrix normal (n, 3, octave_NaN);
  Matrix axis (n, 3, octave_NaN);
  Matrix box (n, 6);
  for (octave_idx_type i = 0; i < n; i++)
  {
    const TopoDS_Face f = TopoDS::Face (map.FindKey (static_cast<int> (i + 1)));
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

// The volume of S, and its centre of volume when CG is true, integrated
// adaptively to a relative error of EPS on every face.  The default
// integration, of fixed order, errs by up to a part in a thousand on spline
// faces.  The centre costs most of the time, so it is computed only when
// asked for.  Should the adaptive integration fail, the default is taken.
static GProp_GProps
volumeprops (const TopoDS_Shape& s, bool cg, double eps)
{
  GProp_GProps p;
  if (BRepGProp::VolumePropertiesGK (s, p, eps, false,
                                     true, cg) < 0)
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
    const BRepAdaptor_Surface g (f, false);
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
  const gp_Pnt p0 = BRep_Tool::Pnt (TopExp::FirstVertex (e, true));
  const gp_Pnt p1 = BRep_Tool::Pnt (TopExp::LastVertex (e, true));
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
    w.Closed (true);
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
    shells[p].Closed (true);
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
    ShapeList objects, tools;
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
    ShapeUpgrade_UnifySameDomain u (s, true, true,
                                    false);
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
  NCollection_Array2<gp_Pnt> P (1, n, 1, m);
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
  return BRepBuilderAPI_Transform (s, t, true).Shape ();
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
    g.a = BRep_Tool::Pnt (TopExp::FirstVertex (g.e, true));
    g.b = BRep_Tool::Pnt (TopExp::LastVertex (g.e, true));
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
  // G is built unplaced, its wires as they lie in F, and placed as F at the
  // end: Add would otherwise take each wire back by the placing of G
  BRep_Builder b;
  TopoDS_Face g = TopoDS::Face (f.EmptyCopied ());
  g.Location (TopLoc_Location ());
  g.Orientation (TopAbs_FORWARD);
  for (TopoDS_Iterator w (f, false, false); w.More ();
       w.Next ())
  {
    TopoDS_Wire nw;
    b.MakeWire (nw);
    int n = 0;
    for (TopoDS_Iterator e (w.Value (), false, false);
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
      nw.Location (w.Value ().Location ());
      nw.Closed (true);
      b.Add (g, nw);
    }
  }
  g.Location (f.Location ());
  g.Orientation (f.Orientation ());
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
      P.push_back (BRep_Tool::Pnt (TopExp::FirstVertex (e, true)));
      Q.push_back (BRep_Tool::Pnt (TopExp::LastVertex (e, true)));
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
  ShapeList tools;
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
  ShapeList objects;
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
  ShapeUpgrade_UnifySameDomain u (kept, true, true,
                                  false);
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
static ShapeMap
solidsof (const TopoDS_Shape& s)
{
  ShapeMap m;
  TopExp::MapShapes (s, TopAbs_SOLID, m);
  return m;
}

// The solids of the shape S, each on its own, or S itself when it holds none
static vector<TopoDS_Shape>
eachsolid (const TopoDS_Shape& s)
{
  const ShapeMap m = solidsof (s);
  vector<TopoDS_Shape> v;
  for (int i = 1; i <= m.Extent (); i++)
  {
    v.push_back (m (i));
  }
  if (v.empty ())
  {
    v.push_back (s);
  }
  return v;
}

// The shapes V as one, the shape itself when there is one
static TopoDS_Shape
gather (const vector<TopoDS_Shape>& v)
{
  if (v.size () == 1)
  {
    return v[0];
  }
  BRep_Builder b;
  TopoDS_Compound c;
  b.MakeCompound (c);
  for (const TopoDS_Shape& s : v)
  {
    b.Add (c, s);
  }
  return c;
}

// What a shape holds besides solids: surfaces, the open shells and the
// faces outside a shell; curves, the wires outside a face and the edges
// outside a wire; points, the vertices outside an edge
struct strays
{
  int surfaces = 0;
  int curves = 0;
  int points = 0;
};

// The solids of S, each closed shell outside a solid made a solid when MAKE
// is true, a null shape when there are none, and in X what else S holds, a
// closed shell among its surfaces when MAKE is false
static TopoDS_Shape
keepsolids (const TopoDS_Shape& s, bool make, strays& x)
{
  vector<TopoDS_Shape> keep;
  for (TopExp_Explorer e (s, TopAbs_SOLID); e.More (); e.Next ())
  {
    keep.push_back (e.Current ());
  }
  for (TopExp_Explorer e (s, TopAbs_SHELL, TopAbs_SOLID); e.More (); e.Next ())
  {
    if (make && BRep_Tool::IsClosed (e.Current ()))
    {
      BRepBuilderAPI_MakeSolid ms (TopoDS::Shell (e.Current ()));
      if (ms.IsDone ())
      {
        TopoDS_Solid so = ms.Solid ();
        BRepLib::OrientClosedSolid (so);
        keep.push_back (so);
        continue;
      }
    }
    x.surfaces++;
  }
  for (TopExp_Explorer e (s, TopAbs_FACE, TopAbs_SHELL); e.More (); e.Next ())
  {
    x.surfaces++;
  }
  for (TopExp_Explorer e (s, TopAbs_WIRE, TopAbs_FACE); e.More (); e.Next ())
  {
    x.curves++;
  }
  for (TopExp_Explorer e (s, TopAbs_EDGE, TopAbs_WIRE); e.More (); e.Next ())
  {
    x.curves++;
  }
  for (TopExp_Explorer e (s, TopAbs_VERTEX, TopAbs_EDGE); e.More (); e.Next ())
  {
    x.points++;
  }
  return keep.empty () ? TopoDS_Shape () : gather (keep);
}

// X in words, as "3 surfaces, 2 curves and 1 point", empty for nothing
static string
describe (const strays& x)
{
  vector<string> w;
  auto add = [&w] (int n, const char *one, const char *many)
  {
    if (n > 0)
    {
      w.push_back (std::to_string (n) + " " + (n == 1 ? one : many));
    }
  };
  add (x.surfaces, "surface", "surfaces");
  add (x.curves, "curve", "curves");
  add (x.points, "point", "points");
  string out;
  for (size_t k = 0; k < w.size (); k++)
  {
    out += (k == 0 ? "" : (k + 1 == w.size () ? " and " : ", ")) + w[k];
  }
  return out;
}

// The error that FILE holds no solid, saying what it holds instead
static void
nosolid (const strays& x, const string& file, const string& caller)
{
  const string left = describe (x);
  if (left.empty ())
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  error ("%s: '%s' holds no solid, only %s.", caller.c_str (), file.c_str (),
         left.c_str ());
}

// The warning that FILE holds X besides its solids, which are left out
static void
leftout (const strays& x, const string& file, const string& caller)
{
  const string left = describe (x);
  if (! left.empty ())
  {
    warning ("%s: '%s' holds %s besides its solids, which %s left out.",
             caller.c_str (), file.c_str (), left.c_str (),
             (x.surfaces + x.curves + x.points == 1) ? "is" : "are");
  }
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
  NCollection_DataMap<TopoDS_Shape, int, TopTools_ShapeMapHasher> owner;
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
    const ShapeMap solids = solidsof (src);
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
  const ShapeMap rs = solidsof (r);
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
  const ShapeMap from = solidsof (s);
  const ShapeMap rs = solidsof (r);
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

// Whether a cut came back without a tool's face that passes inside the shape
// and outside every other tool: such a face bounds the hollow it cuts, so a
// result without it, or without any piece of it, is the shape returned
// uncut, which Open CASCADE 7.8 can report as a success.  Each face is tried
// at the middle of its parameter range, and a face whose middle falls off it
// is passed over.
static bool
uncut (BRepAlgoAPI_BooleanOperation& op)
{
  ShapeMap result;
  TopExp::MapShapes (op.Shape (), TopAbs_FACE, result);
  vector<TopoDS_Shape> tools;
  for (const TopoDS_Shape& t : op.Tools ())
  {
    tools.push_back (t);
  }
  const double tol = Precision::Confusion ();
  for (size_t k = 0; k < tools.size (); k++)
  {
    for (TopExp_Explorer x (tools[k], TopAbs_FACE); x.More (); x.Next ())
    {
      // A face kept, or kept in pieces, needs no point classified
      const TopoDS_Face& f = TopoDS::Face (x.Current ());
      bool kept = result.Contains (f);
      for (const TopoDS_Shape& m : op.Modified (f))
      {
        kept = kept || result.Contains (m);
      }
      if (kept)
      {
        continue;
      }
      double u0, u1, v0, v1;
      BRepTools::UVBounds (f, u0, u1, v0, v1);
      const gp_Pnt2d uv ((u0 + u1) / 2, (v0 + v1) / 2);
      if (BRepClass_FaceClassifier (f, uv, tol).State () != TopAbs_IN)
      {
        continue;
      }
      const gp_Pnt p = BRep_Tool::Surface (f)->Value (uv.X (), uv.Y ());
      bool inside = false;
      for (const TopoDS_Shape& a : op.Arguments ())
      {
        inside = inside
                 || BRepClass3d_SolidClassifier (a, p, tol).State ()
                    == TopAbs_IN;
      }
      for (size_t j = 0; j < tools.size () && inside; j++)
      {
        inside = j == k
                 || BRepClass3d_SolidClassifier (tools[j], p, tol).State ()
                    == TopAbs_OUT;
      }
      if (inside)
      {
        return true;
      }
    }
  }
  return false;
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
  if (op.Operation () == BOPAlgo_CUT && uncut (op))
  {
    error ("%s: Open CASCADE returned the shape uncut although a tool "
           "reaches inside it.", caller.c_str ());
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
  ShapeList objects, list;
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
    op.SetMode (true);
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
    const BRepAdaptor_Surface a (f, false);
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
    BRepBuilderAPI_MakeFace mf (p, BRepTools::OuterWire (f), true);
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
  BRepOffsetAPI_ThruSections op (true, true);
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
  ShapeMap solids;
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

// The solids of the part S at the label L of the document D, S not itself
// a solid, each named by its element of NAMES, in the order a map of them
// gives, unless the element is empty or NAMES has none: a name STEP gives
// the solid itself, not the part
static void
namepart (const xdedoc& d, const TDF_Label& l, const TopoDS_Shape& s,
          const Cell& names)
{
  ShapeMap solids;
  TopExp::MapShapes (s, TopAbs_SOLID, solids);
  for (int i = 1; i <= solids.Extent () && i <= names.numel (); i++)
  {
    const string nm = names(i-1).string_value ();
    if (nm.empty ())
    {
      continue;
    }
    const TDF_Label sub = d.shapes ()->AddSubShape (l, solids (i));
    TDataStd_Name::Set (sub, TCollection_ExtendedString (nm.c_str (), true));
  }
}

// The document D written to FILE as STEP in millimetres, its file named NAME
static void
writedoc (const xdedoc& d, const string& file, const string& name,
          const string& caller)
{
  STEPCAFControl_Writer w;
  w.SetColorMode (true);
  w.SetNameMode (true);
  Interface_Static::SetCVal ("write.step.unit", "MM");
  Interface_Static::SetIVal ("write.stepcaf.subshapes.name", 1);
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

// S as namepart can name its solids by NAMES: a single solid named is put
// in a compound, since STEP names the part by it otherwise
static TopoDS_Shape
named (const TopoDS_Shape& s, const Cell& names)
{
  if (names.numel () == 0 || s.ShapeType () != TopAbs_SOLID)
  {
    return s;
  }
  TopoDS_Compound c;
  BRep_Builder b;
  b.MakeCompound (c);
  b.Add (c, s);
  return c;
}

// S written to FILE as STEP, one part named NAME, its solids coloured as
// colourpart colours them and named as namepart names them
static void
writestep (const TopoDS_Shape& s, const string& file, const string& name,
           const Matrix& colours, const Cell& names, const string& caller)
{
  xdedoc d;
  const TopoDS_Shape t = named (s, names);
  const TDF_Label top = d.shapes ()->AddShape (t, false);
  TDataStd_Name::Set (top, TCollection_ExtendedString (name.c_str (), true));
  colourpart (d, top, t, colours);
  namepart (d, top, t, names);
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
// DATA, the colours of its solids in COLOURS and their own names in SOLIDS,
// as namepart takes them, an assembly by an empty DATA, its placed
// definitions in CHILDREN, a row for each of the index from 1 of the
// definition and the frame it is placed in, as displacement takes it, and
// the names of those placements in INSTANCES
static void
writeassembly (const string& file, const Cell& names, const Cell& data,
               const Cell& colours, const Cell& solids, const Cell& children,
               const Cell& instances, const string& caller)
{
  xdedoc d;
  const octave_idx_type n = names.numel ();
  vector<TDF_Label> label (n);
  for (octave_idx_type i = 0; i < n; i++)
  {
    if (! data(i).isempty ())
    {
      const Cell sn = solids(i).cell_value ();
      const TopoDS_Shape s = named (toshape (data(i), caller), sn);
      label[i] = d.shapes ()->AddShape (s, false);
      colourpart (d, label[i], s, colours(i).matrix_value ());
      namepart (d, label[i], s, sn);
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
  BRepMesh_IncrementalMesh mesh (s, tol, false, angle,
                                 true);
  if (! mesh.IsDone ())
  {
    error ("%s: Open CASCADE could not triangulate the shape.",
           caller.c_str ());
  }
  // Each face with the solid it bounds, the faces of no solid last
  const ShapeMap solids = solidsof (s);
  vector<std::pair<TopoDS_Shape, int>> faces;
  ShapeMap seen;
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
  BRepMesh_IncrementalMesh mesh (s, tol, false, angle,
                                 true);
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

// The solids the STEP file read by R names, each with its name: the name
// of a solid's own entity, never that of the part it belongs to
static vector<std::pair<TopoDS_Shape, string>>
solidnames (STEPCAFControl_Reader& r)
{
  vector<std::pair<TopoDS_Shape, string>> out;
  const Handle (XSControl_WorkSession)& ws = r.ChangeReader ().WS ();
  const Handle (Interface_InterfaceModel) model = ws->Model ();
  const Handle (Transfer_TransientProcess) tp
    = ws->TransferReader ()->TransientProcess ();
  for (int i = 1; i <= model->NbEntities (); i++)
  {
    const Handle (StepShape_ManifoldSolidBrep) b
      = Handle (StepShape_ManifoldSolidBrep)::DownCast (model->Value (i));
    if (b.IsNull () || b->Name ().IsNull () || b->Name ()->Length () == 0)
    {
      continue;
    }
    const TopoDS_Shape x = TransferBRep::ShapeResult (tp, b);
    if (! x.IsNull ())
    {
      out.push_back ({x, b->Name ()->ToCString ()});
    }
  }
  return out;
}

// The name NAMES, as solidnames gives them, has for the solid S, wherever
// it is placed, or empty
static string
nameof (const TopoDS_Shape& s,
        const vector<std::pair<TopoDS_Shape, string>>& names)
{
  for (const auto& xn : names)
  {
    if (xn.first.IsPartner (s))
    {
      return xn.second;
    }
  }
  return "";
}

// The shapes of the STEP file FILE as one shape, in millimetres, and the
// colours and names of its solids, in the order a map of them gives: a
// cell of the shape's bytes, an N-by-3 matrix of red, green and blue from 0
// to 1, a row of NaN for a solid without one, or empty when none has one,
// and a cell column of names, '' for a solid without one, or empty when
// none has one
static Cell
readstep (const string& file, const string& caller)
{
  xdedoc d;
  STEPCAFControl_Reader r;
  r.SetColorMode (true);
  r.SetNameMode (true);
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
  NCollection_Sequence<TDF_Label> roots;
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
  strays x;
  s = keepsolids (s, true, x);
  if (s.IsNull ())
  {
    nosolid (x, file, caller);
  }
  leftout (x, file, caller);
  ShapeMap solids;
  TopExp::MapShapes (s, TopAbs_SOLID, solids);
  const vector<std::pair<TopoDS_Shape, string>> names = solidnames (r);
  Matrix C (solids.Extent (), 3, octave_NaN);
  Cell N (solids.Extent (), 1, octave_value (""));
  bool any = false;
  bool anyname = false;
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
    const string nm = nameof (solids (i), names);
    if (! nm.empty ())
    {
      N(i-1) = nm;
      anyname = true;
    }
  }
  Cell out (1, 3);
  out(0) = todata (s);
  out(1) = any ? C : Matrix ();
  out(2) = anyname ? N : Cell ();
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
// last, then SOLIDS, the names of each part's solids as readstep gives
// them.  A part placed several times is one definition.  Several shapes at
// the top of the file are placed, where they are, in an assembly named
// NAME; a single part is returned as it is.
static Cell
readassembly (const string& file, const string& name, const string& caller)
{
  xdedoc d;
  STEPCAFControl_Reader r;
  r.SetColorMode (true);
  r.SetNameMode (true);
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
  const vector<std::pair<TopoDS_Shape, string>> own = solidnames (r);
  vector<octave_value> names, data, colours, solids, children, instances;
  std::map<string, int> seen;
  // A part with no solid is left out, and an assembly left with no part
  strays x;
  // A name another part has, or another placement in one assembly, is made
  // distinct with _2, _3 and so on, as names in a 3MF file are
  std::set<string> taken;
  auto distinct = [] (std::set<string>& used, const string& n)
  {
    string c = n;
    for (int k = 2; ! used.insert (c).second; k++)
    {
      c = n + "_" + std::to_string (k);
    }
    return c;
  };
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
      NCollection_Sequence<TDF_Label> comps;
      XCAFDoc_ShapeTool::GetComponents (l, comps);
      vector<int> kept;
      vector<TDF_Label> refs;
      for (int k = 1; k <= comps.Length (); k++)
      {
        TDF_Label ref;
        XCAFDoc_ShapeTool::GetReferredShape (comps (k), ref);
        const int v = visit (ref);
        if (v >= 0)
        {
          kept.push_back (k);
          refs.push_back (ref);
        }
      }
      if (kept.empty ())
      {
        seen[entry.ToCString ()] = -1;
        return -1;
      }
      Matrix C (kept.size (), 13);
      Cell inst (1, kept.size ());
      std::set<string> placed;
      for (size_t q = 0; q < kept.size (); q++)
      {
        const int k = kept[q];
        const int v = visit (refs[q]);
        C(q,0) = v + 1;
        double f[12];
        frameof (XCAFDoc_ShapeTool::GetLocation (comps (k)), f, caller);
        for (int j = 0; j < 12; j++)
        {
          C(q,j+1) = f[j];
        }
        const string in = labelname (comps (k));
        inst(q) = distinct (placed,
                            in.empty () ? names[v].string_value () : in);
      }
      names.push_back (distinct (taken, nm.empty () ? "assembly" : nm));
      data.push_back (uint8NDArray (dim_vector (0, 0)));
      colours.push_back (Matrix ());
      solids.push_back (Cell ());
      children.push_back (C);
      instances.push_back (inst);
    }
    else
    {
      const TopoDS_Shape s = keepsolids (XCAFDoc_ShapeTool::GetShape (l),
                                         true, x);
      if (s.IsNull ())
      {
        seen[entry.ToCString ()] = -1;
        return -1;
      }
      const ShapeMap sm = solidsof (s);
      Matrix C (sm.Extent (), 3, octave_NaN);
      Cell N (sm.Extent (), 1, octave_value (""));
      bool any = false;
      bool anyname = false;
      for (int i = 1; i <= sm.Extent (); i++)
      {
        Quantity_Color c;
        if (colourof (d, sm (i), c))
        {
          double rgb[3];
          c.Values (rgb[0], rgb[1], rgb[2], Quantity_TOC_sRGB);
          for (int k = 0; k < 3; k++)
          {
            C(i-1,k) = rgb[k];
          }
          any = true;
        }
        const string sn = nameof (sm (i), own);
        if (! sn.empty ())
        {
          N(i-1) = sn;
          anyname = true;
        }
      }
      names.push_back (distinct (taken, nm.empty () ? "part" : nm));
      data.push_back (todata (s));
      colours.push_back (any ? C : Matrix ());
      solids.push_back (anyname ? N : Cell ());
      children.push_back (Matrix ());
      instances.push_back (Cell ());
    }
    const int k = names.size () - 1;
    seen[entry.ToCString ()] = k;
    return k;
  };
  NCollection_Sequence<TDF_Label> roots;
  d.shapes ()->GetFreeShapes (roots);
  if (roots.Length () == 0)
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  vector<int> top;
  for (int i = 1; i <= roots.Length (); i++)
  {
    const int v = visit (roots (i));
    if (v >= 0)
    {
      top.push_back (v);
    }
  }
  if (top.empty ())
  {
    nosolid (x, file, caller);
  }
  leftout (x, file, caller);
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
    solids.push_back (Cell ());
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
  Cell out (1, 6);
  out(0) = tocell (names);
  out(1) = tocell (data);
  out(2) = tocell (colours);
  out(3) = tocell (children);
  out(4) = tocell (instances);
  out(5) = tocell (solids);
  return out;
}

// Knurling.  A knurl is laid out on its face unrolled, in the angle theta
// round the axis and z along it, where each flank of a groove is a sheet
// r = a + b theta + c z.  The unrolled face is cut into polygons, each lying
// on one sheet or on the fillet or chamfer of an end, those on the same
// surface are joined where they share a side, and each is built as a face on
// its true surface.  No boolean is involved, which makes a knurl twenty times
// faster than cutting its grooves.
namespace knurling
{

// A polygon in the unrolled face, its corners (theta, z)
typedef vector<pair<double, double>> poly;

// The sheet r = a + b theta + c z, numbered sid among the skin's surfaces
struct sheet
{
  double a, b, c;
  int sid;
};

// The treatment of one end of the face: none (0), a fillet (1) or a chamfer
// (2) of size t
struct treatment
{
  int type = 0;
  double t = 0;
  double zc = 0;     // the centre of a fillet along the axis
  double rmaj = 0;   // the radius a fillet's centre runs round at
  double zref = 0;   // where a chamfer's cone is measured from
  double ang = 0;    // a chamfer's half angle
  int sid = -1;
  int sign = 0;      // +1 at Z0, -1 at Z1: the direction into the face
  double zend = 0;
};

// One polygon of the skin, lying on the surface sid.  Side i runs from
// corner i to the next, straight in the unrolled face unless arc(i) is set,
// when it is the crease where the sheet ep(i) meets the treatment of the end
// ee(i).
struct patch
{
  vector<double> t, z;
  vector<char> arc;
  vector<sheet> ep;
  vector<int> ee;
  sheet p;           // the sheet the polygon lies on, when a flank
  int sid;
  int end;           // the end whose treatment it meets, or -1
};

// The cylinder of radius R from Z0 to Z1 and the treatments of its ends
struct blank
{
  double R, z0, z1;
  treatment E[2];

  // The radius of the end K's treatment at Z, R beyond its reach
  double env (int k, double z) const
  {
    const treatment& e = E[k];
    const double d = e.sign * (z - e.zend);
    if (e.type == 0 || d >= e.t)
    {
      return R;
    }
    if (e.type == 2)
    {
      return R - e.t + d;
    }
    const double q = e.t - d;
    return R - e.t + sqrt (std::max (e.t * e.t - q * q, 0.0));
  }

  // The angle round the tube of the fillet at the end K, at Z
  double vof (int k, double z) const
  {
    const treatment& e = E[k];
    return asin (std::min (std::max ((z - e.zc) / e.t, -1.0), 1.0));
  }
};

// One set of grooves (raised) or ridges (indented), running where w = s cos A
// - z sin A is constant, s the length round the face: its pitch P, its count
// round the face, and its pieces along w, r = al + be w on [w0, w1]
struct grooveset
{
  double ca, sa, P;
  int count;
  vector<double> w0, w1, al, be;
};

// The knurl asked for: its pitch, its depth (0 for the full depth), the
// angle of its teeth in degrees, the angle of each set of grooves from the
// axis in degrees, whether its points are indented, and the type and size of
// the treatment at each end
struct knurlspec
{
  double pitch, depth, profile;
  vector<double> angles;
  bool indented;
  double ends[2][2];
};

static double
polyarea (const poly& Q)
{
  double a = 0;
  for (size_t i = 0; i < Q.size (); i++)
  {
    const size_t j = (i + 1) % Q.size ();
    a += Q[i].first * Q[j].second - Q[j].first * Q[i].second;
  }
  return a / 2;
}

// The part of Q where a theta + b z + d >= 0
static poly
clip (const poly& Q, double a, double b, double d)
{
  poly out;
  const size_t n = Q.size ();
  if (n == 0)
  {
    return out;
  }
  vector<double> f (n);
  const double s = std::max (1.0, hypot (a, b));
  for (size_t i = 0; i < n; i++)
  {
    f[i] = a * Q[i].first + b * Q[i].second + d;
    if (std::abs (f[i]) < 1e-12 * s)
    {
      f[i] = 0;
    }
  }
  for (size_t i = 0; i < n; i++)
  {
    const size_t j = (i + 1) % n;
    if (f[i] >= 0)
    {
      out.push_back (Q[i]);
    }
    if (f[i] * f[j] < 0)
    {
      const double w = f[i] / (f[i] - f[j]);
      out.push_back ({Q[i].first + w * (Q[j].first - Q[i].first),
                      Q[i].second + w * (Q[j].second - Q[i].second)});
    }
  }
  poly q;
  for (size_t i = 0; i < out.size (); i++)
  {
    const auto& p1 = out[i];
    const auto& p2 = out[(i + 1) % out.size ()];
    if (hypot (p1.first - p2.first, p1.second - p2.second) > 1e-10)
    {
      q.push_back (p1);
    }
  }
  return q;
}

// How far the sheet P stands above the treatment of the end K at (T, Z)
static double
hval (const blank& K, int k, const sheet& p, double t, double z)
{
  return p.a + p.b * t + p.c * z - K.env (k, z);
}

// Where hval changes sign strictly inside the segment from (T0, Z0) to
// (T1, Z1), as fractions of it; hval is convex along a segment, so it has
// two roots at most
static vector<double>
roots (const blank& K, int k, const sheet& p, double t0, double z0,
       double t1, double z1)
{
  auto f = [&] (double s)
  {
    return hval (K, k, p, t0 + s * (t1 - t0), z0 + s * (z1 - z0));
  };
  auto bisect = [&] (double a, double b)
  {
    double fa = f (a);
    for (int i = 0; i < 200 && b - a > 1e-15; i++)
    {
      const double m = (a + b) / 2;
      const double fm = f (m);
      if ((fa < 0) == (fm < 0))
      {
        a = m;
        fa = fm;
      }
      else
      {
        b = m;
      }
    }
    return (a + b) / 2;
  };
  vector<double> r;
  const double fa = f (0);
  const double fb = f (1);
  if (fa * fb < 0 && std::abs (fa) > 1e-12 && std::abs (fb) > 1e-12)
  {
    r.push_back (bisect (0, 1));
    return r;
  }
  // Both ends on one side: the minimum, by golden section, decides
  double a = 0;
  double b = 1;
  const double g = (sqrt (5.0) - 1) / 2;
  double x1 = b - g * (b - a);
  double x2 = a + g * (b - a);
  double f1 = f (x1);
  double f2 = f (x2);
  for (int i = 0; i < 100; i++)
  {
    if (f1 < f2)
    {
      b = x2;
      x2 = x1;
      f2 = f1;
      x1 = b - g * (b - a);
      f1 = f (x1);
    }
    else
    {
      a = x1;
      x1 = x2;
      f1 = f2;
      x2 = a + g * (b - a);
      f2 = f (x2);
    }
  }
  const double tm = (a + b) / 2;
  if (f (tm) < -1e-12)
  {
    if (fa > 1e-12)
    {
      r.push_back (bisect (0, tm));
    }
    if (fb > 1e-12)
    {
      r.push_back (bisect (tm, 1));
    }
  }
  return r;
}

// The polygon Q on the sheet P, every side straight
static patch
plain (const poly& Q, const sheet& p, int sid, int end)
{
  patch F;
  for (const auto& q : Q)
  {
    F.t.push_back (q.first);
    F.z.push_back (q.second);
    F.arc.push_back (0);
    F.ep.push_back (p);
    F.ee.push_back (end);
  }
  F.p = p;
  F.sid = sid;
  F.end = end;
  return F;
}

// The polygon Q on the sheet P split where it meets the treatment of the end
// K: below the crease the sheet, beyond it the treatment.  False when Q meets
// the crease more than twice, and must be cut smaller first.
static bool
split (const blank& K, int k, const poly& Q, const sheet& p,
       vector<patch>& out)
{
  struct corner
  {
    double t, z;
    int side;
  };
  vector<corner> L;
  const size_t n = Q.size ();
  auto side = [] (double h)
  {
    return h < -1e-12 ? -1 : (h > 1e-12 ? 1 : 0);
  };
  for (size_t i = 0; i < n; i++)
  {
    const size_t j = (i + 1) % n;
    L.push_back ({Q[i].first, Q[i].second,
                  side (hval (K, k, p, Q[i].first, Q[i].second))});
    for (double s : roots (K, k, p, Q[i].first, Q[i].second,
                           Q[j].first, Q[j].second))
    {
      L.push_back ({Q[i].first + s * (Q[j].first - Q[i].first),
                    Q[i].second + s * (Q[j].second - Q[i].second), 0});
    }
  }
  int zeros = 0;
  for (const corner& c : L)
  {
    zeros += (c.side == 0);
  }
  if (zeros > 2)
  {
    return false;
  }
  for (int s : {-1, 1})
  {
    vector<size_t> keep;
    bool any = false;
    for (size_t i = 0; i < L.size (); i++)
    {
      if (L[i].side == 0 || L[i].side == s)
      {
        keep.push_back (i);
        any = any || L[i].side == s;
      }
    }
    if (! any)
    {
      continue;
    }
    patch F;
    F.p = p;
    F.sid = s < 0 ? p.sid : K.E[k].sid;
    F.end = k;
    for (size_t m = 0; m < keep.size (); m++)
    {
      const size_t i = keep[m];
      const size_t j = keep[(m + 1) % keep.size ()];
      bool line = false;
      if ((i + 1) % L.size () == j)
      {
        const double h = hval (K, k, p, (L[i].t + L[j].t) / 2,
                               (L[i].z + L[j].z) / 2);
        line = s < 0 ? h <= 1e-12 : h >= -1e-12;
      }
      F.t.push_back (L[i].t);
      F.z.push_back (L[i].z);
      F.arc.push_back (! line);
      F.ep.push_back (p);
      F.ee.push_back (k);
    }
    if (F.t.size () >= 3 || (F.t.size () == 2 && (F.arc[0] || F.arc[1])))
    {
      out.push_back (F);
    }
  }
  return true;
}

// The handles of arrays the curve interpolators take, which Open CASCADE 8.0
// names by their element type
#if OCC_VERSION_MAJOR >= 8
using PointArray = NCollection_HArray1<gp_Pnt>;
using Point2dArray = NCollection_HArray1<gp_Pnt2d>;
using RealArray = NCollection_HArray1<double>;
#else
using PointArray = TColgp_HArray1OfPnt;
using Point2dArray = TColgp_HArray1OfPnt2d;
using RealArray = TColStd_HArray1OfReal;
#endif

// The sheet P over theta from T0 to T1 and z from Z0 to Z1: cubic in theta
// through a point every quarter of a degree, linear in z, its parameters
// theta and z.  An interpolated curve's parameter strays a little from
// theta between its points, which moves the edges of a face along it: at a
// point a degree, over the small range of one face, enough to change a
// knurl's volume by a part in ten million.
static Handle (Geom_Surface)
flank (const sheet& p, double t0, double t1, double z0, double z1)
{
  const int n = std::max (8, static_cast<int> (ceil ((t1 - t0)
                                                     / (M_PI / 720))) + 1);
  Handle (RealArray) par = new RealArray (1, n);
  Handle (PointArray) p0 = new PointArray (1, n);
  Handle (PointArray) p1 = new PointArray (1, n);
  for (int i = 1; i <= n; i++)
  {
    const double t = t0 + (t1 - t0) * (i - 1) / (n - 1);
    par->SetValue (i, t);
    const double r0 = p.a + p.b * t + p.c * z0;
    const double r1 = p.a + p.b * t + p.c * z1;
    p0->SetValue (i, gp_Pnt (r0 * cos (t), r0 * sin (t), z0));
    p1->SetValue (i, gp_Pnt (r1 * cos (t), r1 * sin (t), z1));
  }
  GeomAPI_Interpolate i0 (p0, par, false, 1e-12);
  GeomAPI_Interpolate i1 (p1, par, false, 1e-12);
  i0.Perform ();
  i1.Perform ();
  const Handle (Geom_BSplineCurve) c0 = i0.Curve ();
  const Handle (Geom_BSplineCurve) c1 = i1.Curve ();
  NCollection_Array2<gp_Pnt> P (1, c0->NbPoles (), 1, 2);
  for (int i = 1; i <= c0->NbPoles (); i++)
  {
    P(i,1) = c0->Pole (i);
    P(i,2) = c1->Pole (i);
  }
  NCollection_Array1<double> vk (1, 2);
  vk(1) = z0;
  vk(2) = z1;
  NCollection_Array1<int> vm (1, 2);
  vm(1) = 2;
  vm(2) = 2;
  return new Geom_BSplineSurface (P, c0->Knots (), vk, c0->Multiplicities (),
                                  vm, c0->Degree (), 1);
}

// The 2-D curve through the points P, evenly parametrised
static Handle (Geom2d_Curve)
interp2d (const vector<gp_Pnt2d>& P)
{
  const int n = P.size ();
  Handle (Point2dArray) pts = new Point2dArray (1, n);
  Handle (RealArray) par = new RealArray (1, n);
  for (int i = 0; i < n; i++)
  {
    pts->SetValue (i + 1, P[i]);
    par->SetValue (i + 1, static_cast<double> (i) / (n - 1));
  }
  Geom2dAPI_Interpolate I (pts, par, false, 1e-12);
  I.Perform ();
  return I.Curve ();
}

// The sheet P of a set of grooves at the angle whose cosine and sine are CA
// and SA, laid along the groove: its parameters are w = R CA theta - SA z
// across the groove, from W0 to W1, and l = R SA theta + CA z along it, from
// L0 to L1.  A single knurl's flank is a strip round the face, and a surface
// laid in theta and z would span the face's whole height to hold it.  It
// interpolates a grid, cubic both ways: curves along l, a point every
// quarter of a degree of theta, through the same parameters, then their
// poles across w.
static Handle (Geom_Surface)
groove (const sheet& p, double ca, double sa, double R, double w0, double w1,
        double l0, double l1)
{
  auto deg = [] (double turn)
  {
    return std::max (8, static_cast<int> (ceil (turn / (M_PI / 720))) + 1);
  };
  const int nw = deg (std::abs (ca) * (w1 - w0) / R);
  const int nl = deg (std::abs (sa) * (l1 - l0) / R);
  Handle (RealArray) lpar = new RealArray (1, nl);
  for (int i = 1; i <= nl; i++)
  {
    lpar->SetValue (i, l0 + (l1 - l0) * (i - 1) / (nl - 1));
  }
  vector<Handle (Geom_BSplineCurve)> rows;
  for (int k = 0; k < nw; k++)
  {
    const double w = w0 + (w1 - w0) * k / (nw - 1);
    Handle (PointArray) pts = new PointArray (1, nl);
    for (int i = 1; i <= nl; i++)
    {
      const double l = lpar->Value (i);
      const double t = (ca * w + sa * l) / R;
      const double z = - sa * w + ca * l;
      const double r = p.a + p.b * t + p.c * z;
      pts->SetValue (i, gp_Pnt (r * cos (t), r * sin (t), z));
    }
    GeomAPI_Interpolate I (pts, lpar, false, 1e-12);
    I.Perform ();
    rows.push_back (I.Curve ());
  }
  const int np = rows[0]->NbPoles ();
  Handle (RealArray) wpar = new RealArray (1, nw);
  for (int k = 1; k <= nw; k++)
  {
    wpar->SetValue (k, w0 + (w1 - w0) * (k - 1) / (nw - 1));
  }
  vector<Handle (Geom_BSplineCurve)> cols;
  for (int j = 1; j <= np; j++)
  {
    Handle (PointArray) pts = new PointArray (1, nw);
    for (int k = 1; k <= nw; k++)
    {
      pts->SetValue (k, rows[k-1]->Pole (j));
    }
    GeomAPI_Interpolate I (pts, wpar, false, 1e-12);
    I.Perform ();
    cols.push_back (I.Curve ());
  }
  const int mp = cols[0]->NbPoles ();
  NCollection_Array2<gp_Pnt> P (1, mp, 1, np);
  for (int m = 1; m <= mp; m++)
  {
    for (int j = 1; j <= np; j++)
    {
      P(m,j) = cols[j-1]->Pole (m);
    }
  }
  return new Geom_BSplineSurface (P, cols[0]->Knots (), rows[0]->Knots (),
                                  cols[0]->Multiplicities (),
                                  rows[0]->Multiplicities (),
                                  cols[0]->Degree (), rows[0]->Degree ());
}

// The sets of grooves of the knurl SPEC on the cylinder of radius R and
// length H, each pitch fitted to a whole count round the face, or along it
// for rings, and the depth D they are cut to
static vector<grooveset>
groovesets (double R, double H, const knurlspec& spec, double& D,
            const string& caller)
{
  const double L = 2 * M_PI * R;
  const double prof = spec.profile * M_PI / 180;
  vector<grooveset> sets;
  double full = 1e300;
  for (double a : spec.angles)
  {
    grooveset s;
    const bool ring = std::abs (std::abs (a) - 90) < 1e-12;
    s.ca = ring ? 0 : cos (a * M_PI / 180);
    s.sa = ring ? (a > 0 ? 1 : -1) : sin (a * M_PI / 180);
    if (ring)
    {
      s.count = std::max (1, static_cast<int> (lround (H / spec.pitch)));
      s.P = H / s.count;
    }
    else
    {
      s.count = std::max (1, static_cast<int> (lround (L * s.ca
                                                       / spec.pitch)));
      s.P = L * s.ca / s.count;
    }
    full = std::min (full, s.P / (2 * tan (prof / 2)));
    sets.push_back (s);
  }
  D = spec.depth > 0 ? spec.depth : full;
  if (D > full * (1 + 1e-12))
  {
    error ("%s: DEPTH must be no more than %.4g, the full depth of the"
           " teeth at the pitch fitted round F.", caller.c_str (), full);
  }
  return sets;
}

// The knurled skin of the cylinder of radius R from Z0 to Z1 about the z
// axis, the low point of its first set of grooves at theta 0 and Z0, as a
// shell open at both ends
static TopoDS_Shape
skin (double R, double z0, double z1, const knurlspec& spec,
      const string& caller)
{
  blank K;
  K.R = R;
  K.z0 = z0;
  K.z1 = z1;
  const double L = 2 * M_PI * R;
  const double H = z1 - z0;
  const double prof = spec.profile * M_PI / 180;
  const double ct = 1 / tan (prof / 2);       // the slope of a flank, dr/dw
  const bool indented = spec.indented;
  double D;
  vector<grooveset> sets = groovesets (R, H, spec, D, caller);
  const double e = D / ct;                  // half the width of a groove at R

  // The surfaces of the skin, numbered by name
  map<string, int> sidof;
  vector<string> keys;
  auto sid = [&] (const string& k)
  {
    auto it = sidof.find (k);
    if (it != sidof.end ())
    {
      return it->second;
    }
    const int n = keys.size ();
    sidof[k] = n;
    keys.push_back (k);
    return n;
  };
  const int cylR = sid ("cylinder R");
  const int cylD = sid ("cylinder R-D");

  // The ends
  for (int k = 0; k < 2; k++)
  {
    treatment& E = K.E[k];
    E.type = static_cast<int> (spec.ends[k][0]);
    E.t = spec.ends[k][1];
    E.sign = k == 0 ? 1 : -1;
    E.zend = k == 0 ? z0 : z1;
    if (E.type == 1)
    {
      E.zc = E.zend + E.sign * E.t;
      E.rmaj = R - E.t;
      E.sid = sid (k == 0 ? "torus 0" : "torus 1");
    }
    else if (E.type == 2)
    {
      E.zref = k == 0 ? z0 : z1 - E.t;
      E.ang = k == 0 ? M_PI / 4 : -M_PI / 4;
      E.sid = sid (k == 0 ? "cone 0" : "cone 1");
    }
  }
  if (K.E[0].t >= R || K.E[1].t >= R)
  {
    error ("%s: a fillet or chamfer must be smaller than the radius of F.",
           caller.c_str ());
  }
  if (K.E[0].t + K.E[1].t > H)
  {
    error ("%s: the fillets or chamfers at the two ends of F overlap.",
           caller.c_str ());
  }

  // The pieces of each set along w, the low point of a groove (raised) or
  // of a pit (indented) at theta 0 and Z0
  for (grooveset& s : sets)
  {
    double wa = 1e300;
    double wb = -1e300;
    for (double ss : {0.0, L})
    {
      for (double zz : {z0, z1})
      {
        const double w = ss * s.ca - zz * s.sa;
        wa = std::min (wa, w);
        wb = std::max (wb, w);
      }
    }
    const double wl = - z0 * s.sa;
    const long k0 = static_cast<long> (floor ((wa - wl) / s.P)) - 1;
    const long k1 = static_cast<long> (ceil ((wb - wl) / s.P)) + 1;
    for (long k = k0; k <= k1; k++)
    {
      if (! indented)
      {
        const double g = wl + k * s.P;
        s.w0.push_back (g - e);
        s.w1.push_back (g);
        s.al.push_back (R - D + ct * g);
        s.be.push_back (-ct);
        s.w0.push_back (g);
        s.w1.push_back (g + e);
        s.al.push_back (R - D - ct * g);
        s.be.push_back (ct);
        if (s.P - 2 * e > 1e-12)
        {
          s.w0.push_back (g + e);
          s.w1.push_back (g + s.P - e);
          s.al.push_back (R);
          s.be.push_back (0);
        }
      }
      else
      {
        const double q = wl + (k + 0.5) * s.P;
        s.w0.push_back (q - e);
        s.w1.push_back (q);
        s.al.push_back (R - ct * q);
        s.be.push_back (ct);
        s.w0.push_back (q);
        s.w1.push_back (q + e);
        s.al.push_back (R + ct * q);
        s.be.push_back (-ct);
        if (s.P - 2 * e > 1e-12)
        {
          s.w0.push_back (q + e);
          s.w1.push_back (q + s.P - e);
          s.al.push_back (R - D);
          s.be.push_back (0);
        }
      }
    }
  }
  // A single knurl takes a second set of one piece at R, which never wins
  if (sets.size () == 1)
  {
    grooveset s;
    s.ca = 1;
    s.sa = 0;
    s.P = 0;
    s.count = 0;
    s.w0.push_back (-1e300);
    s.w1.push_back (1e300);
    s.al.push_back (R);
    s.be.push_back (0);
    sets.push_back (s);
  }
  auto piece = [&] (int j, size_t i)
  {
    const grooveset& s = sets[j];
    sheet p;
    p.a = s.al[i];
    p.b = s.be[i] * R * s.ca;
    p.c = - s.be[i] * s.sa;
    if (s.be[i] == 0)
    {
      p.sid = s.al[i] == R ? cylR : cylD;
    }
    else
    {
      p.sid = sid ("flank " + to_string (j) + " " + to_string (i));
    }
    return p;
  };

  // Zones along z: a band all treatment, where a treatment reaches below the
  // grooves; treated; plain; treated; band
  struct zone
  {
    double za, zb;
    int kind;        // 0 plain, 1 treated, 2 band
    int end;
  };
  vector<zone> Z;
  const double rlow = R - D;
  double zb0 = z0;
  double zb1 = z1;
  for (int k = 0; k < 2; k++)
  {
    const treatment& E = K.E[k];
    if (E.type == 0)
    {
      continue;
    }
    const double lo = R - E.t;
    if (lo < rlow - 1e-9)
    {
      double dz;
      if (E.type == 2)
      {
        dz = rlow - lo;
      }
      else
      {
        dz = E.t - sqrt (E.t * E.t - (rlow - lo) * (rlow - lo));
      }
      (k == 0 ? zb0 : zb1) = E.zend + E.sign * dz / 2;
    }
  }
  if (zb0 > z0)
  {
    Z.push_back ({z0, zb0, 2, 0});
  }
  const double zt0 = z0 + K.E[0].t;
  const double zt1 = z1 - K.E[1].t;
  if (K.E[0].type)
  {
    Z.push_back ({zb0, zt0, 1, 0});
  }
  Z.push_back ({K.E[0].type ? zt0 : z0, K.E[1].type ? zt1 : z1, 0, -1});
  if (K.E[1].type)
  {
    Z.push_back ({zt1, zb1, 1, 1});
  }
  if (zb1 < z1)
  {
    Z.push_back ({zb1, z1, 2, 1});
  }

  // The polygons
  vector<patch> faces;
  auto keepface = [&] (const patch& F)
  {
    faces.push_back (F);
  };
  bool overflow = false;
  vector<patch> pend;
  auto add = [&] (poly Q, const sheet& p, const zone& z)
  {
    if (polyarea (Q) < 0)
    {
      reverse (Q.begin (), Q.end ());
    }
    if (Q.size () < 3 || polyarea (Q) < 1e-14)
    {
      return;
    }
    if (z.kind == 1)
    {
      if (! split (K, z.end, Q, p, pend))
      {
        overflow = true;
      }
    }
    else
    {
      pend.push_back (plain (Q, p, p.sid, -1));
    }
  };
  // Q between w = A and w = B of the set S, w = R ca theta - sa z
  auto wclip = [&] (const poly& Q, const grooveset& s, double a, double b)
  {
    if (s.P == 0)
    {
      return Q;
    }
    return clip (clip (Q, R * s.ca, -s.sa, -a), -R * s.ca, s.sa, b);
  };
  for (const zone& zn : Z)
  {
    if (zn.kind == 2 || zn.zb - zn.za < 1e-12)
    {
      continue;
    }
    // A treated zone is cut into bands, more of them until no polygon meets
    // the crease more than twice: a long flank can cross a fillet four times
    for (int nb = 1; ; nb *= 2)
    {
      overflow = false;
      pend.clear ();
      const int nslab = zn.kind == 1 ? nb : 1;
      for (int sl = 0; sl < nslab && ! overflow; sl++)
      {
        zone z = zn;
        z.za = zn.za + (zn.zb - zn.za) * sl / nslab;
        z.zb = sl + 1 == nslab ? zn.zb
                               : zn.za + (zn.zb - zn.za) * (sl + 1) / nslab;
        const poly box {{0, z.za}, {2 * M_PI, z.za}, {2 * M_PI, z.zb},
                        {0, z.zb}};
        const grooveset& s1 = sets[0];
        const grooveset& s2 = sets[1];
        for (size_t i = 0; i < s1.w0.size (); i++)
        {
          const poly Q1 = wclip (box, s1, s1.w0[i], s1.w1[i]);
          if (Q1.size () < 3)
          {
            continue;
          }
          double wa = 1e300;
          double wb = -1e300;
          for (const auto& q : Q1)
          {
            const double w = s2.P == 0 ? 0 : R * s2.ca * q.first
                                             - s2.sa * q.second;
            wa = std::min (wa, w);
            wb = std::max (wb, w);
          }
          const size_t j0 = lower_bound (s2.w1.begin (), s2.w1.end (), wa)
                            - s2.w1.begin ();
          for (size_t j = j0; j < s2.w0.size () && s2.w0[j] < wb; j++)
          {
            const poly Q = wclip (Q1, s2, s2.w0[j], s2.w1[j]);
            if (Q.size () < 3)
            {
              continue;
            }
            const sheet p1 = piece (0, i);
            const sheet p2 = piece (1, j);
            if (s2.be[j] == 0)
            {
              add (Q, p1, z);
            }
            else if (s1.be[i] == 0)
            {
              add (Q, p2, z);
            }
            else
            {
              // Where both sets cut, the lower sheet wins when raised and
              // the higher when indented
              const double a = p2.b - p1.b;
              const double b = p2.c - p1.c;
              const double d = p2.a - p1.a;
              add (clip (Q, a, b, d), indented ? p2 : p1, z);
              add (clip (Q, -a, -b, -d), indented ? p1 : p2, z);
            }
          }
        }
      }
      if (! overflow)
      {
        for (const patch& F : pend)
        {
          keepface (F);
        }
        break;
      }
      if (nb >= 256)
      {
        error ("%s: the knurl could not be laid out along the fillet or"
               " chamfer of F.", caller.c_str ());
      }
    }
  }
  // The bands, all treatment, their inner sides through the corners the
  // polygons next to them leave there
  for (const zone& z : Z)
  {
    if (z.kind != 2)
    {
      continue;
    }
    const double zin = z.end == 0 ? z.zb : z.za;
    const double zout = z.end == 0 ? z.za : z.zb;
    vector<double> pts;
    for (const patch& F : faces)
    {
      for (size_t m = 0; m < F.z.size (); m++)
      {
        if (std::abs (F.z[m] - zin) < 1e-12)
        {
          pts.push_back (F.t[m]);
        }
      }
    }
    sort (pts.begin (), pts.end ());
    vector<double> tt;
    for (double x : pts)
    {
      if (tt.empty () || x - tt.back () > 1e-10)
      {
        tt.push_back (x);
      }
    }
    const size_t step = 8;
    for (size_t a = 0; a + 1 < tt.size (); a += step)
    {
      const size_t b = std::min (a + step, tt.size () - 1);
      patch F;
      F.p = {0, 0, 0, -1};
      F.sid = K.E[z.end].sid;
      F.end = z.end;
      auto put = [&] (double th, double zz)
      {
        F.t.push_back (th);
        F.z.push_back (zz);
        F.arc.push_back (0);
        F.ep.push_back (F.p);
        F.ee.push_back (z.end);
      };
      if (z.end == 0)
      {
        put (tt[a], zout);
        put (tt[b], zout);
        for (size_t m = b; m > a; m--)
        {
          put (tt[m], zin);
        }
        put (tt[a], zin);
      }
      else
      {
        for (size_t m = a; m <= b; m++)
        {
          put (tt[m], zin);
        }
        put (tt[b], zout);
        put (tt[a], zout);
      }
      keepface (F);
    }
  }

  // Polygons on one surface that share a straight side are joined into one,
  // which Open CASCADE's own unifying does not do reliably here
  typedef pair<long long, long long> vkey;
  auto key = [] (double a, double b)
  {
    return make_pair (llround (a * 1e9), llround (b * 1e9));
  };
  map<pair<vkey, vkey>, vector<size_t>> owner;
  for (size_t f = 0; f < faces.size (); f++)
  {
    const patch& F = faces[f];
    for (size_t i = 0; i < F.t.size (); i++)
    {
      if (F.arc[i])
      {
        continue;
      }
      const size_t j = (i + 1) % F.t.size ();
      owner[minmax (key (F.t[i], F.z[i]), key (F.t[j], F.z[j]))]
        .push_back (f);
    }
  }
  vector<size_t> up (faces.size ());
  for (size_t f = 0; f < up.size (); f++)
  {
    up[f] = f;
  }
  function<size_t (size_t)> root = [&] (size_t f)
  {
    return up[f] == f ? f : up[f] = root (up[f]);
  };
  for (const auto& kv : owner)
  {
    if (kv.second.size () == 2)
    {
      const size_t f = kv.second[0];
      const size_t g = kv.second[1];
      if (f != g && faces[f].sid == faces[g].sid)
      {
        up[root (f)] = root (g);
      }
    }
  }
  map<size_t, vector<size_t>> groups;
  for (size_t f = 0; f < faces.size (); f++)
  {
    groups[root (f)].push_back (f);
  }
  vector<patch> merged;
  for (const auto& gv : groups)
  {
    const vector<size_t>& G = gv.second;
    if (G.size () == 1)
    {
      merged.push_back (faces[G[0]]);
      continue;
    }
    // The sides of the group, those it holds both ways dropped, followed
    // round from one to the next
    struct side
    {
      vkey a, b;
      double ta, za;
      char arc;
      sheet p;
      int end;
    };
    map<pair<vkey, vkey>, int> count;
    vector<side> all;
    for (size_t f : G)
    {
      const patch& F = faces[f];
      for (size_t i = 0; i < F.t.size (); i++)
      {
        const size_t j = (i + 1) % F.t.size ();
        const side d {key (F.t[i], F.z[i]), key (F.t[j], F.z[j]), F.t[i],
                      F.z[i], F.arc[i], F.ep[i], F.ee[i]};
        all.push_back (d);
        count[{d.a, d.b}]++;
      }
    }
    map<vkey, vector<size_t>> from;
    for (size_t k = 0; k < all.size (); k++)
    {
      if (all[k].arc || ! count.count ({all[k].b, all[k].a}))
      {
        from[all[k].a].push_back (k);
      }
    }
    bool ok = ! from.empty ();
    for (const auto& kv : from)
    {
      ok = ok && kv.second.size () == 1;
    }
    patch M;
    if (ok)
    {
      size_t k = from.begin ()->second[0];
      const vkey start = all[k].a;
      size_t n = 0;
      do
      {
        M.t.push_back (all[k].ta);
        M.z.push_back (all[k].za);
        M.arc.push_back (all[k].arc);
        M.ep.push_back (all[k].p);
        M.ee.push_back (all[k].end);
        const auto it = from.find (all[k].b);
        if (it == from.end ())
        {
          ok = false;
          break;
        }
        k = it->second[0];
        n++;
      }
      while (all[k].a != start && n <= from.size ());
      ok = ok && n == from.size ();
    }
    if (ok)
    {
      M.p = faces[G[0]].p;
      M.sid = faces[G[0]].sid;
      M.end = faces[G[0]].end;
      merged.push_back (M);
    }
    else
    {
      for (size_t f : G)
      {
        merged.push_back (faces[f]);
      }
    }
  }
  faces.swap (merged);

  // The surfaces: cylinders at R and R - D, a torus or a cone at each
  // treated end, and each flank over the theta its polygons span
  const int ns = keys.size ();
  vector<Handle (Geom_Surface)> S (ns);
  vector<int> stype (ns, 0);    // 0 (theta, z) itself, 1 torus, 2 cone
  vector<int> send (ns, -1);
  S[cylR] = new Geom_CylindricalSurface (gp_Ax3 (gp::XOY ()), R);
  S[cylD] = new Geom_CylindricalSurface (gp_Ax3 (gp::XOY ()), R - D);
  for (int k = 0; k < 2; k++)
  {
    const treatment& E = K.E[k];
    if (E.type == 1)
    {
      S[E.sid] = new Geom_ToroidalSurface (gp_Ax3 (gp_Pnt (0, 0, E.zc),
                                                   gp::DZ (), gp::DX ()),
                                           E.rmaj, E.t);
      stype[E.sid] = 1;
    }
    else if (E.type == 2)
    {
      S[E.sid] = new Geom_ConicalSurface (gp_Ax3 (gp_Pnt (0, 0, E.zref),
                                                  gp::DZ (), gp::DX ()),
                                          E.ang, k == 0 ? R - E.t : R);
      stype[E.sid] = 2;
    }
    if (E.type)
    {
      send[E.sid] = k;
    }
  }
  // A flank surface for each face, over the face's own range, so that its
  // poles stay close to the face: Open CASCADE boxes a face by its whole
  // surface, and a box much larger than the face slows every later boolean.
  // A single knurl's flank is laid along its groove.
  const bool helical = spec.angles.size () == 1
                       && std::abs (spec.angles[0]) > 1e-12;
  const double gca = sets[0].ca;
  const double gsa = sets[0].sa;
  auto alongw = [&] (double th, double z)
  {
    return R * gca * th - gsa * z;
  };
  auto alongl = [&] (double th, double z)
  {
    return R * gsa * th + gca * z;
  };
  vector<Handle (Geom_Surface)> fs (faces.size ());
  for (size_t f = 0; f < faces.size (); f++)
  {
    const patch& F = faces[f];
    if (keys[F.sid].compare (0, 5, "flank") != 0)
    {
      continue;
    }
    // The face's corners and the points of its creases, (theta, z)
    vector<pair<double, double>> pts;
    for (size_t i = 0; i < F.t.size (); i++)
    {
      pts.push_back ({F.t[i], F.z[i]});
    }
    // A crease on a fillet can bulge past the face's corners
    for (size_t i = 0; i < F.t.size (); i++)
    {
      const int ke = F.ee[i];
      const sheet& pe = F.ep[i];
      if (! F.arc[i] || ke < 0 || K.E[ke].type != 1
          || std::abs (pe.b) <= 1e-12)
      {
        continue;
      }
      const treatment& E = K.E[ke];
      const size_t j = (i + 1) % F.t.size ();
      const double v1 = K.vof (ke, F.z[i]);
      const double v2 = K.vof (ke, F.z[j]);
      for (int m = 1; m < 32; m++)
      {
        const double v = v1 + (v2 - v1) * m / 32;
        const double z = E.zc + E.t * sin (v);
        const double th = (E.rmaj + E.t * cos (v) - pe.a - pe.c * z) / pe.b;
        pts.push_back ({th, z});
      }
    }
    double a0 = 1e300;
    double a1 = -1e300;
    double b0 = 1e300;
    double b1 = -1e300;
    for (const auto& q : pts)
    {
      const double a = helical ? alongw (q.first, q.second) : q.first;
      const double b = helical ? alongl (q.first, q.second) : q.second;
      a0 = std::min (a0, a);
      a1 = std::max (a1, a);
      b0 = std::min (b0, b);
      b1 = std::max (b1, b);
    }
    if (helical)
    {
      fs[f] = groove (F.p, gca, gsa, R, a0 - 1e-3, a1 + 1e-3, b0 - 1e-3,
                      b1 + 1e-3);
    }
    else
    {
      fs[f] = flank (F.p, a0 - M_PI / 360, a1 + M_PI / 360, b0 - 1e-3,
                     b1 + 1e-3);
    }
  }

  // The faces, sewn into the skin.  A crease on a fillet is sampled evenly in
  // the torus angle, since in z its slope is infinite at the end face.
  const int N = 33;
  auto uv = [&] (int s, double th, double z)
  {
    if (stype[s] == 1)
    {
      return gp_Pnt2d (th, K.vof (send[s], z));
    }
    if (stype[s] == 2)
    {
      const treatment& E = K.E[send[s]];
      return gp_Pnt2d (th, (z - E.zref) / cos (E.ang));
    }
    return gp_Pnt2d (th, z);
  };
  BRepBuilderAPI_Sewing sew (1e-6);
  for (size_t f = 0; f < faces.size (); f++)
  {
    const patch& F = faces[f];
    const int s = F.sid;
    const Handle (Geom_Surface)& surf = fs[f].IsNull () ? S[s] : fs[f];
    const bool along = helical && ! fs[f].IsNull ();
    auto at = [&] (double th, double z)
    {
      return along ? gp_Pnt2d (alongw (th, z), alongl (th, z))
                   : uv (s, th, z);
    };
    const size_t n = F.t.size ();
    vector<TopoDS_Vertex> V (n);
    for (size_t i = 0; i < n; i++)
    {
      const gp_Pnt2d q = at (F.t[i], F.z[i]);
      V[i] = BRepBuilderAPI_MakeVertex (surf->Value (q.X (), q.Y ()))
               .Vertex ();
    }
    BRepBuilderAPI_MakeWire mw;
    for (size_t i = 0; i < n; i++)
    {
      const size_t j = (i + 1) % n;
      const gp_Pnt2d a = at (F.t[i], F.z[i]);
      const gp_Pnt2d b = at (F.t[j], F.z[j]);
      const sheet& pe = F.ep[i];
      const int ke = F.ee[i];
      const bool curved = F.arc[i] && ke >= 0 && K.E[ke].type == 1
                          && std::abs (pe.b) > 1e-12;
      const bool torusline = ! F.arc[i] && stype[s] == 1
                             && std::abs (F.z[i] - F.z[j]) > 1e-12
                             && std::abs (F.t[i] - F.t[j]) > 1e-12;
      Handle (Geom2d_Curve) cv;
      double p1 = 0;
      double p2 = 1;
      if (curved || torusline)
      {
        const int k = curved ? ke : send[s];
        const treatment& E = K.E[k];
        const double v1 = K.vof (k, F.z[i]);
        const double v2 = K.vof (k, F.z[j]);
        vector<gp_Pnt2d> pts {a};
        for (int m = 1; m < N - 1; m++)
        {
          const double v = v1 + (v2 - v1) * m / (N - 1);
          const double z = E.zc + E.t * sin (v);
          double th;
          if (curved)
          {
            th = (E.rmaj + E.t * cos (v) - pe.a - pe.c * z) / pe.b;
          }
          else
          {
            th = F.t[i] + (F.t[j] - F.t[i]) * (z - F.z[i]) / (F.z[j] - F.z[i]);
          }
          pts.push_back (at (th, z));
        }
        pts.push_back (b);
        cv = interp2d (pts);
      }
      else
      {
        const gp_Vec2d dv (a, b);
        cv = new Geom2d_Line (a, gp_Dir2d (dv));
        p2 = dv.Magnitude ();
      }
      mw.Add (BRepBuilderAPI_MakeEdge (cv, surf, V[i], V[j], p1, p2).Edge ());
    }
    TopoDS_Face face = BRepBuilderAPI_MakeFace (surf, mw.Wire (), true).Face ();
    BRepLib::BuildCurves3d (face, 1e-7);
    sew.Add (face);
  }
  sew.Perform ();
  return sew.SewedShape ();
}

// The signed area the wire W encloses in the plane of the axes AX, its edges
// in the order and sense they take in it
static double
wirearea (const TopoDS_Wire& w, const gp_Ax3& ax)
{
  vector<gp_Pnt> p;
  for (TopExp_Explorer x (w, TopAbs_EDGE); x.More (); x.Next ())
  {
    const TopoDS_Edge e = TopoDS::Edge (x.Current ());
    BRepAdaptor_Curve c (e);
    const double f = c.FirstParameter ();
    const double l = c.LastParameter ();
    const bool rev = e.Orientation () == TopAbs_REVERSED;
    for (int k = 0; k < 16; k++)
    {
      p.push_back (c.Value (rev ? l - (l - f) * k / 16 : f + (l - f) * k / 16));
    }
  }
  double a = 0;
  const gp_Dir X = ax.XDirection ();
  const gp_Dir Y = ax.YDirection ();
  const gp_Pnt O = ax.Location ();
  for (size_t i = 0; i < p.size (); i++)
  {
    const gp_Vec u (O, p[i]);
    const gp_Vec v (O, p[(i + 1) % p.size ()]);
    a += u.Dot (X) * v.Dot (Y) - v.Dot (X) * u.Dot (Y);
  }
  return a / 2;
}

// Whether the solid S fills the ring about the axes AX from radius R0 to R1
// and from Z0 to Z1 along the axis
static bool
wholering (const TopoDS_Shape& s, const gp_Ax3& ax, double r0, double r1,
           double z0, double z1, const string& caller)
{
  const gp_Ax2 a (ax.Location ().Translated (gp_Vec (ax.Direction ()) * z0),
                  ax.Direction ());
  TopoDS_Shape ring = BRepPrimAPI_MakeCylinder (a, r1, z1 - z0).Shape ();
  if (r0 > 0)
  {
    BRepAlgoAPI_Cut cut (ring,
                         BRepPrimAPI_MakeCylinder (a, r0, z1 - z0).Shape ());
    ring = boolean (cut, caller, "knurl");
  }
  BRepAlgoAPI_Common op (s, ring);
  const double v = volumeprops (ring, false, 1e-9).Mass ();
  return volumeprops (boolean (op, caller, "knurl"), false, 1e-9).Mass ()
         >= v * (1 - 1e-6);
}

// The solid SO with its face F knurled: F replaced by the knurled skin, the
// flat face at each end of F given the knurl's outline in place of its
// circle, and every other face kept.  TREAT has a row for each treatment,
// the index in S of the edge it treats, or 0 for every free end left, its
// type and its size.
static TopoDS_Shape
knurlsolid (const TopoDS_Shape& so, const TopoDS_Face& F, const ShapeMap& emap,
            knurlspec spec, const Matrix& treat, const string& caller)
{
  const char *who = caller.c_str ();
  BRepAdaptor_Surface ad (F);
  const gp_Cylinder cy = ad.Cylinder ();
  const double R = cy.Radius ();
  const gp_Ax3 ax (cy.Location (), cy.Axis ().Direction (),
                   cy.XAxis ().Direction ());
  double u0, u1, v0, v1;
  BRepTools::UVBounds (F, u0, u1, v0, v1);
  if (u1 - u0 < 2 * M_PI - 1e-9)
  {
    error ("%s: F must go all the way round its axis.", who);
  }
  {
    gp_Pnt p;
    gp_Vec du, dv;
    ad.D1 ((u0 + u1) / 2, (v0 + v1) / 2, p, du, dv);
    gp_Vec n = du.Crossed (dv);
    if (F.Orientation () == TopAbs_REVERSED)
    {
      n.Reverse ();
    }
    gp_Vec rad (ax.Location (), p);
    rad -= gp_Vec (ax.Direction ()) * rad.Dot (gp_Vec (ax.Direction ()));
    if (n.Dot (rad) <= 0)
    {
      error ("%s: F must be an outside face, not a bore.", who);
    }
  }
  auto zof = [&] (const gp_Pnt& p)
  {
    return gp_Vec (ax.Location (), p).Dot (gp_Vec (ax.Direction ()));
  };
  double z0 = 1e300;
  double z1 = -1e300;
  for (TopExp_Explorer x (F, TopAbs_VERTEX); x.More (); x.Next ())
  {
    const double z = zof (BRep_Tool::Pnt (TopoDS::Vertex (x.Current ())));
    z0 = std::min (z0, z);
    z1 = std::max (z1, z);
  }

  // The ends: their circles, and the flat face each meets
  ShapeListMap e2f;
  TopExp::MapShapesAndAncestors (so, TopAbs_EDGE, TopAbs_FACE, e2f);
  vector<TopoDS_Edge> endE[2];
  TopoDS_Face P[2];
  for (TopExp_Explorer x (F, TopAbs_EDGE); x.More (); x.Next ())
  {
    const TopoDS_Edge e = TopoDS::Edge (x.Current ());
    if (BRep_Tool::Degenerated (e) || BRep_Tool::IsClosed (e, F))
    {
      continue;
    }
    BRepAdaptor_Curve c (e);
    const double z = zof (c.Value ((c.FirstParameter ()
                                    + c.LastParameter ()) / 2));
    const int k = std::abs (z - z0) < 1e-6 ? 0
                  : (std::abs (z - z1) < 1e-6 ? 1 : -1);
    if (k < 0 || c.GetType () != GeomAbs_Circle)
    {
      error ("%s: F must end in a circle at each end.", who);
    }
    bool seen = false;
    for (const TopoDS_Edge& f : endE[k])
    {
      seen = seen || f.IsSame (e);
    }
    if (seen)
    {
      continue;
    }
    endE[k].push_back (e);
    for (const TopoDS_Shape& q : e2f.FindFromKey (e))
    {
      if (! q.IsSame (F))
      {
        if (P[k].IsNull ())
        {
          P[k] = TopoDS::Face (q);
        }
        else if (! P[k].IsSame (q))
        {
          error ("%s: each end of F must meet one flat face square to its"
                 " axis.", who);
        }
      }
    }
  }
  bool shoulder[2];
  for (int k = 0; k < 2; k++)
  {
    if (P[k].IsNull ())
    {
      error ("%s: each end of F must meet one flat face square to its"
             " axis.", who);
    }
    BRepAdaptor_Surface pa (P[k]);
    if (pa.GetType () != GeomAbs_Plane
        || ! pa.Plane ().Axis ().Direction ().IsParallel (ax.Direction (),
                                                          1e-9))
    {
      error ("%s: each end of F must meet one flat face square to its"
             " axis.", who);
    }
    // A shoulder: the end face reaches beyond F
    shoulder[k] = false;
    for (TopExp_Explorer x (P[k], TopAbs_EDGE); x.More (); x.Next ())
    {
      BRepAdaptor_Curve c (TopoDS::Edge (x.Current ()));
      for (int m = 0; m <= 4; m++)
      {
        const gp_Pnt p = c.Value (c.FirstParameter ()
                                  + (c.LastParameter ()
                                     - c.FirstParameter ()) * m / 4);
        gp_Vec r (ax.Location (), p);
        r -= gp_Vec (ax.Direction ()) * r.Dot (gp_Vec (ax.Direction ()));
        shoulder[k] = shoulder[k] || r.Magnitude () > R + 1e-6;
      }
    }
  }

  // The treatments: first those named by their edge, then a size for every
  // free end left, given as edge 0
  for (int k = 0; k < 2; k++)
  {
    spec.ends[k][0] = spec.ends[k][1] = 0;
  }
  for (octave_idx_type i = 0; i < treat.rows (); i++)
  {
    const int ei = static_cast<int> (treat(i,0));
    if (ei == 0)
    {
      continue;
    }
    int k = -1;
    for (int kk = 0; kk < 2; kk++)
    {
      for (const TopoDS_Edge& f : endE[kk])
      {
        if (f.IsSame (emap (ei)))
        {
          k = kk;
        }
      }
    }
    if (k < 0)
    {
      error ("%s: edge %d is not at an end of F.", who, ei);
    }
    if (shoulder[k])
    {
      error ("%s: edge %d is where F meets a shoulder, so it cannot be"
             " filleted or chamfered.", who, ei);
    }
    if (spec.ends[k][0] != 0)
    {
      error ("%s: an end of F can take one fillet or chamfer only.", who);
    }
    spec.ends[k][0] = treat(i,1);
    spec.ends[k][1] = treat(i,2);
  }
  for (octave_idx_type i = 0; i < treat.rows (); i++)
  {
    if (treat(i,0) != 0)
    {
      continue;
    }
    bool used = false;
    for (int k = 0; k < 2; k++)
    {
      if (! shoulder[k] && spec.ends[k][0] == 0)
      {
        spec.ends[k][0] = treat(i,1);
        spec.ends[k][1] = treat(i,2);
        used = true;
      }
    }
    if (! used)
    {
      error ("%s: F has no free end left to %s.", who,
             treat(i,1) == 1 ? "fillet" : "chamfer");
    }
  }

  // The teeth reach in to R - D along F, a fillet or chamfer of size T to
  // R - T at its end, and the material there must be whole: a bore reaching
  // into it would be cut through.  The rings stop GAP short of F and its
  // ends, so as not to lie on them, and a wall under them thinner than GAP
  // counts as none.
  const double gap = 1e-3;
  double D;
  groovesets (R, z1 - z0, spec, D, caller);
  if (! wholering (so, ax, R - D - gap, R - gap, z0 + gap, z1 - gap,
                   caller))
  {
    error ("%s: the teeth, %.4g deep, would cut into a bore of S.", who, D);
  }
  for (int k = 0; k < 2; k++)
  {
    const double t = spec.ends[k][1];
    if (spec.ends[k][0] == 0 || t >= R || t >= z1 - z0)
    {
      continue;
    }
    if (! wholering (so, ax, R - t - gap, R - gap,
                     k == 0 ? z0 + gap : z1 - t,
                     k == 0 ? z0 + t : z1 - gap, caller))
    {
      error ("%s: the %s of %.4g at an end of F would cut into a bore of S.",
             who, spec.ends[k][0] == 1 ? "fillet" : "chamfer", t);
    }
  }

  // The knurled skin, built about the z axis and put on the axis of F, its
  // first groove at the cylinder's own x direction
  TopoDS_Shape side = skin (R, z0, z1, spec, caller);
  gp_Trsf place;
  place.SetDisplacement (gp_Ax3 (gp::XOY ()), ax);
  side = BRepBuilderAPI_Transform (side, place, false).Shape ();

  // Each end face with its circle replaced by the outline of the knurl
  ShapeAnalysis_FreeBounds fb (side, false, false);
  TopoDS_Wire W[2];
  for (TopExp_Explorer x (fb.GetClosedWires (), TopAbs_WIRE); x.More ();
       x.Next ())
  {
    const TopoDS_Wire w = TopoDS::Wire (x.Current ());
    TopExp_Explorer vx (w, TopAbs_VERTEX);
    const double z = zof (BRep_Tool::Pnt (TopoDS::Vertex (vx.Current ())));
    const int k = std::abs (z - z0) < 1e-6 ? 0
                  : (std::abs (z - z1) < 1e-6 ? 1 : -1);
    if (k < 0 || ! W[k].IsNull ())
    {
      error ("%s: Open CASCADE could not close the knurl at the ends of F.",
             who);
    }
    W[k] = w;
  }
  if (W[0].IsNull () || W[1].IsNull ())
  {
    error ("%s: Open CASCADE could not close the knurl at the ends of F.",
           who);
  }
  BRep_Builder bb;
  TopoDS_Face N[2];
  for (int k = 0; k < 2; k++)
  {
    const TopoDS_Face Pf = TopoDS::Face (P[k].Oriented (TopAbs_FORWARD));
    TopoDS_Wire old;
    for (TopExp_Explorer x (Pf, TopAbs_WIRE); x.More (); x.Next ())
    {
      for (TopExp_Explorer y (x.Current (), TopAbs_EDGE); y.More (); y.Next ())
      {
        if (y.Current ().IsSame (endE[k][0]))
        {
          old = TopoDS::Wire (x.Current ());
        }
      }
    }
    bool whole = ! old.IsNull ();
    for (TopExp_Explorer y (old, TopAbs_EDGE); whole && y.More (); y.Next ())
    {
      bool ours = false;
      for (const TopoDS_Edge& f : endE[k])
      {
        ours = ours || f.IsSame (y.Current ());
      }
      whole = ours;
    }
    if (! whole)
    {
      error ("%s: each end of F must be a whole loop of the face it meets.",
             who);
    }
    TopoDS_Wire nw = W[k];
    if ((wirearea (old, ax) > 0) != (wirearea (nw, ax) > 0))
    {
      nw.Reverse ();
    }
    TopoDS_Face Nf = TopoDS::Face (Pf.EmptyCopied ());
    for (TopExp_Explorer x (Pf, TopAbs_WIRE); x.More (); x.Next ())
    {
      bb.Add (Nf, x.Current ().IsSame (old) ? TopoDS_Shape (nw)
                                            : x.Current ());
    }
    N[k] = Nf;
  }

  // The solid again: every face but F and its end faces, the new end faces
  // and the knurled skin
  TopoDS_Solid out;
  bb.MakeSolid (out);
  for (TopExp_Explorer x (so, TopAbs_SHELL); x.More (); x.Next ())
  {
    TopoDS_Shell sh;
    bb.MakeShell (sh);
    bool touched = false;
    for (TopExp_Explorer y (x.Current (), TopAbs_FACE); y.More (); y.Next ())
    {
      const TopoDS_Shape& f = y.Current ();
      if (f.IsSame (F))
      {
        touched = true;
        continue;
      }
      const int k = f.IsSame (P[0]) ? 0 : (f.IsSame (P[1]) ? 1 : -1);
      bb.Add (sh, k < 0 ? f : N[k].Oriented (f.Orientation ()));
    }
    if (touched)
    {
      for (TopExp_Explorer y (side, TopAbs_FACE); y.More (); y.Next ())
      {
        bb.Add (sh, y.Current ());
      }
    }
    sh.Closed (true);
    bb.Add (out, sh);
  }
  if (! BRepCheck_Analyzer (out).IsValid ())
  {
    error ("%s: Open CASCADE could not knurl F.", who);
  }
  return out;
}

// The shape S with its face of index FI knurled, its other solids as they
// were and in the same order
static TopoDS_Shape
knurl (const TopoDS_Shape& s, int fi, const knurlspec& spec,
       const Matrix& treat, const string& caller)
{
  ShapeMap fmap;
  ShapeMap emap;
  TopExp::MapShapes (s, TopAbs_FACE, fmap);
  TopExp::MapShapes (s, TopAbs_EDGE, emap);
  const TopoDS_Face F = TopoDS::Face (fmap (fi));
  vector<TopoDS_Shape> parts = eachsolid (s);
  for (TopoDS_Shape& so : parts)
  {
    ShapeMap own;
    TopExp::MapShapes (so, TopAbs_FACE, own);
    if (own.Contains (F))
    {
      so = knurlsolid (so, F, emap, spec, treat, caller);
      break;
    }
  }
  return gather (parts);
}

}

// The arguments of a call, read by position.  Each command reads the ones it
// needs without counting them first; one past the end of the list raises an
// error instead of reading beyond it.
class arglist
{
public:
  arglist (const octave_value_list& a, const string& cmd)
    : m_a (a), m_cmd (cmd)
  { }

  const octave_value& operator () (octave_idx_type k) const
  {
    if (k >= m_a.length ())
    {
      error ("__occt__: too few arguments for '%s'.", m_cmd.c_str ());
    }
    return m_a(k);
  }

  octave_idx_type length () const
  {
    return m_a.length ();
  }

private:
  const octave_value_list& m_a;
  const string m_cmd;
};

DEFUN_DLD (__occt__, given, ,
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
  if (given.length () < 2 || ! given(0).is_string ()
      || ! given(1).is_string ())
  {
    error ("__occt__: invalid number of input arguments.");
  }
  const string cmd = given(0).string_value ();
  const string caller = given(1).string_value ();
  const arglist args (given, cmd);

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
        ShapeList sides;
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
          ShapeList objects, tools;
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
        BRepOffsetAPI_ThruSections op (true, ruled);
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
      const ShapeList edges
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
          ShapeMap fmap;
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
          ShapeMap fmap;
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
      const ShapeList open
        = picked (s, TopAbs_FACE, args(3).array_value ());
      // The walls grow inwards, or outwards when asked, each the default
      // thickness unless given one of its own
      const bool outward = (args.length () > 5 && args(5).bool_value ());
      const double sign = outward ? 1 : -1;
      const double t = args(4).double_value ();
      BRepOffset_MakeOffset op;
      op.Initialize (s, sign * t, 1e-6, BRepOffset_Skin, false,
                     false, GeomAbs_Intersection);
      for (const TopoDS_Shape& f : open)
      {
        op.AddFace (TopoDS::Face (f));
      }
      if (args.length () > 7)
      {
        const NDArray fi = args(6).array_value ();
        const NDArray ft = args(7).array_value ();
        const ShapeList thick = picked (s, TopAbs_FACE, fi);
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
          ShapeList objects, tools;
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

    // A knurl on the cylindrical face F: its pitch, its depth (0 for the
    // full depth), the angle of each set of grooves, whether its points are
    // indented, the angle of its teeth, and a row [EDGE, TYPE, SIZE] for each
    // fillet (TYPE 1) or chamfer (TYPE 2), EDGE 0 for every free end left
    else if (cmd == "knurl")
    {
      const TopoDS_Shape s = toshape (args(2), caller);
      knurling::knurlspec spec;
      spec.pitch = args(4).double_value ();
      spec.depth = args(5).double_value ();
      const NDArray a = args(6).array_value ();
      spec.angles.assign (a.data (), a.data () + a.numel ());
      spec.indented = args(7).bool_value ();
      spec.profile = args(8).double_value ();
      const TopoDS_Shape r = knurling::knurl (s, args(3).int_value (), spec,
                                              args(9).matrix_value (), caller);
      out = traced (r, itself (count (s, TopAbs_SOLID)));
    }

    // Booleans.  A union and a difference take every solid after the first
    // shape as a tool in one operation, which is several times faster than
    // taking them one at a time.  An intersection cannot: Open CASCADE
    // intersects the first shape with the union of the tools, so it goes
    // pairwise.  Open CASCADE takes no shape whose solids overlap, as an
    // assembly's do: given one it returns a wrong result and reports
    // nothing.  So every operation takes the solids of each shape on its own.
    // Solids whose boxes meet are fused in groups, and a solid that meets
    // none is kept as it is.  Open CASCADE intersects every pair of faces
    // whose boxes overlap, and it boxes a spline face by its poles, which can
    // stand well outside the face, so solids that do not touch can still
    // cost it minutes: two knurled knobs 16 apart took 8 s, and 21 apart half
    // a second.
    else if (cmd == "fuse")
    {
      vector<TopoDS_Shape> solids;
      for (int i = 2; i < args.length (); i++)
      {
        for (const TopoDS_Shape& p : eachsolid (toshape (args(i), caller)))
        {
          solids.push_back (p);
        }
      }
      const int n = solids.size ();
      Matrix B (n, 6);
      for (int i = 0; i < n; i++)
      {
        boxrow (solids[i], B, i);
      }
      double tol = 1;
      for (octave_idx_type k = 0; k < B.numel (); k++)
      {
        tol = std::max (tol, std::abs (B(k)));
      }
      tol *= 1e-9;
      vector<int> up (n);
      for (int i = 0; i < n; i++)
      {
        up[i] = i;
      }
      function<int (int)> root = [&] (int i)
      {
        return up[i] == i ? i : up[i] = root (up[i]);
      };
      for (int i = 0; i < n; i++)
      {
        for (int j = i + 1; j < n; j++)
        {
          bool meet = true;
          for (int c = 0; c < 3 && meet; c++)
          {
            meet = B(i,c+3) >= B(j,c) - tol && B(i,c) <= B(j,c+3) + tol;
          }
          if (meet)
          {
            up[root (i)] = root (j);
          }
        }
      }
      map<int, vector<int>> groups;
      for (int i = 0; i < n; i++)
      {
        groups[root (i)].push_back (i);
      }
      vector<TopoDS_Shape> results;
      origins L;
      for (const auto& g : groups)
      {
        const vector<int>& G = g.second;
        if (G.size () == 1)
        {
          results.push_back (solids[G[0]]);
          L.push_back ({G[0] + 1});
          continue;
        }
        ShapeList objects, tools;
        vector<TopoDS_Shape> src;
        for (int i : G)
        {
          (src.empty () ? objects : tools).Append (solids[i]);
          src.push_back (solids[i]);
        }
        BRepAlgoAPI_Fuse op;
        op.SetArguments (objects);
        op.SetTools (tools);
        const TopoDS_Shape r = boolean (op, caller, "union");
        for (const std::set<int>& o : lineage (op, src, r))
        {
          std::set<int> h;
          for (int k : o)
          {
            h.insert (G[k-1] + 1);
          }
          L.push_back (h);
        }
        results.push_back (r);
      }
      out = traced (gather (results), L);
    }
    else if (cmd == "cut")
    {
      // Each solid of the first shape cut on its own by every solid of the
      // others, since Open CASCADE cuts overlapping solids from one another
      vector<TopoDS_Shape> sources {toshape (args(2), caller)};
      ShapeList tools;
      for (int i = 3; i < args.length (); i++)
      {
        sources.push_back (toshape (args(i), caller));
        for (const TopoDS_Shape& p : eachsolid (sources.back ()))
        {
          tools.Append (p);
        }
      }
      const vector<TopoDS_Shape> objects = eachsolid (sources[0]);
      const int n = count (sources[0], TopAbs_SOLID);
      const int m = (n > 0 ? 1 : 0);
      vector<TopoDS_Shape> results;
      origins L;
      for (size_t j = 0; j < objects.size (); j++)
      {
        ShapeList one;
        one.Append (objects[j]);
        BRepAlgoAPI_Cut op;
        op.SetArguments (one);
        op.SetTools (tools);
        const TopoDS_Shape r = boolean (op, caller, "difference");
        vector<TopoDS_Shape> src (sources);
        src[0] = objects[j];
        for (const std::set<int>& o : lineage (op, src, r))
        {
          std::set<int> g;
          for (int k : o)
          {
            g.insert (k <= m ? int (j) + 1 : k - m + n);
          }
          L.push_back (g);
        }
        results.push_back (r);
      }
      out = traced (gather (results), L);
    }
    else if (cmd == "common")
    {
      // Pairwise, each step's lineage carried back to the operands' solids,
      // numbered all in turn: SEEN of them before the shape intersected
      // next.  The solids of that shape are joined first into the region
      // they cover, and each solid so far is intersected with it on its own.
      TopoDS_Shape s = toshape (args(2), caller);
      origins L = itself (count (s, TopAbs_SOLID));
      int seen = L.size ();
      for (int i = 3; i < args.length () && count (s, TopAbs_FACE) > 0; i++)
      {
        const TopoDS_Shape t = toshape (args(i), caller);
        const int nt = count (t, TopAbs_SOLID);
        TopoDS_Shape region = t;
        origins R = itself (nt);
        if (nt > 1)
        {
          const vector<TopoDS_Shape> parts = eachsolid (t);
          ShapeList first, rest;
          first.Append (parts[0]);
          for (size_t k = 1; k < parts.size (); k++)
          {
            rest.Append (parts[k]);
          }
          BRepAlgoAPI_Fuse join;
          join.SetArguments (first);
          join.SetTools (rest);
          region = boolean (join, caller, "intersection");
          R = lineage (join, {t}, region);
        }
        const vector<TopoDS_Shape> objects = eachsolid (s);
        const int m = (count (s, TopAbs_SOLID) > 0 ? 1 : 0);
        vector<TopoDS_Shape> results;
        origins next;
        for (size_t j = 0; j < objects.size (); j++)
        {
          ShapeList one, tools;
          one.Append (objects[j]);
          tools.Append (region);
          BRepAlgoAPI_Common op;
          op.SetArguments (one);
          op.SetTools (tools);
          const TopoDS_Shape r = boolean (op, caller, "intersection");
          for (const std::set<int>& o : lineage (op, {objects[j], region}, r))
          {
            std::set<int> g;
            for (int k : o)
            {
              if (k <= m)
              {
                g.insert (L[j].begin (), L[j].end ());
              }
              else
              {
                for (int q : R[k-m-1])
                {
                  g.insert (seen + q);
                }
              }
            }
            next.push_back (g);
          }
          results.push_back (r);
        }
        seen += nt;
        L = next;
        s = gather (results);
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
                                    true);
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
    // face of it, without the edges lying inside it, comes back as its outer
    // loop and its inner loops.
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
        BRep_Builder b;
        TopoDS_Compound c;
        b.MakeCompound (c);
        for (TopExp_Explorer x (boolean (op, caller, "section"), TopAbs_FACE);
             x.More (); x.Next ())
        {
          b.Add (c, withoutinternal (TopoDS::Face (x.Current ())));
        }
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
        ShapeList pos, neg;
        for (size_t i = 0; i < W.size (); i++)
        {
          const bool fill = (A[i] > 0) == (big > 0);
          const TopoDS_Wire w = (A[i] > 0) ? W[i]
                                           : TopoDS::Wire (W[i].Reversed ());
          BRepBuilderAPI_MakeFace mf (w, true);
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
            ShapeList first, rest = pos;
            first.Append (rest.First ());
            rest.RemoveFirst ();
            BRepAlgoAPI_Fuse b;
            b.SetArguments (first);
            b.SetTools (rest);
            u = boolean (b, caller, "text");
          }
          if (! neg.IsEmpty ())
          {
            ShapeList first;
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
        ShapeList first, rest;
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
                                    true);
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
          ShapeList first, rest;
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
          ShapeList first, rest;
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
      out = volumeprops (toshape (args(2), caller), false,
                         args(3).double_value ()).Mass ();
    }
    else if (cmd == "area")
    {
      out = area (toshape (args(2), caller));
    }
    else if (cmd == "centroid")
    {
      const GProp_GProps p = volumeprops (toshape (args(2), caller), true,
                                          args(3).double_value ());
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
      BRepBndLib::AddOptimal (toshape (args(2), caller), b, false,
                              false);
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
    // What the shape holds besides solids, in words, empty for nothing
    else if (cmd == "strays")
    {
      strays x;
      keepsolids (toshape (args(2), caller), false, x);
      out = describe (x);
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
                 args(4).string_value (), args(5).matrix_value (),
                 args(6).cell_value (), caller);
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
                     args(6).cell_value (), args(7).cell_value (),
                     args(8).cell_value (), caller);
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
    // The Open CASCADE release built against, which tests may depend on
    else if (cmd == "version")
    {
      out = OCC_VERSION_COMPLETE;
    }
    else
    {
      error ("__occt__: unknown command '%s'.", cmd.c_str ());
    }
  }
  catch (const Standard_Failure& e)
  {
    const char *msg = failure (e);
    if (msg != nullptr && *msg != '\0')
    {
      error ("%s: Open CASCADE failed: %s (%s).", caller.c_str (), msg,
             failurekind (e));
    }
    error ("%s: Open CASCADE failed (%s).", caller.c_str (),
           failurekind (e));
  }

  return ovl (out);
}

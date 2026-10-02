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

#include <cmath>
#include <sstream>
#include <string>

#include <octave/oct.h>

#include <APIHeaderSection_MakeHeader.hxx>
#include <BRepAlgoAPI_BooleanOperation.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BinTools.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <Interface_Static.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <Standard_Failure.hxx>
#include <StlAPI_Writer.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
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

// A transformed copy of a shape
static TopoDS_Shape
transform (const TopoDS_Shape& s, const gp_Trsf& t)
{
  return BRepBuilderAPI_Transform (s, t, Standard_True).Shape ();
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

static void
writestep (const TopoDS_Shape& s, const string& file, const string& name,
           const string& caller)
{
  STEPControl_Writer w;
  Interface_Static::SetCVal ("write.step.unit", "MM");
  Interface_Static::SetCVal ("write.step.product.name", name.c_str ());
  if (w.Transfer (s, STEPControl_AsIs) != IFSelect_RetDone)
  {
    error ("%s: Open CASCADE could not translate the shape to STEP.",
           caller.c_str ());
  }
  APIHeaderSection_MakeHeader header (w.Model ());
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

static void
writestl (const TopoDS_Shape& s, const string& file, double tol,
          double angle, const string& caller)
{
  BRepMesh_IncrementalMesh mesh (s, tol, Standard_False, angle,
                                 Standard_True);
  if (! mesh.IsDone ())
  {
    error ("%s: Open CASCADE could not triangulate the shape.",
           caller.c_str ());
  }
  StlAPI_Writer w;
  w.ASCIIMode () = Standard_False;
  if (! w.Write (s, file.c_str ()))
  {
    error ("%s: cannot write '%s'.", caller.c_str (), file.c_str ());
  }
}

static TopoDS_Shape
readstep (const string& file, const string& caller)
{
  STEPControl_Reader r;
  Interface_Static::SetCVal ("xstep.cascade.unit", "MM");
  if (r.ReadFile (file.c_str ()) != IFSelect_RetDone)
  {
    error ("%s: cannot read '%s' as a STEP file.", caller.c_str (),
           file.c_str ());
  }
  if (r.TransferRoots () == 0)
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  return r.OneShape ();
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
                                              args(3).double_value ()).Shape ());
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

    // Booleans.  A union and a difference take every shape after the first
    // as a tool in one operation, which is several times faster than taking
    // them one at a time.  An intersection cannot: Open CASCADE intersects
    // the first shape with the union of the tools, so it goes pairwise.
    else if (cmd == "fuse" || cmd == "cut")
    {
      TopTools_ListOfShape objects, tools;
      objects.Append (toshape (args(2), caller));
      for (int i = 3; i < args.length (); i++)
      {
        tools.Append (toshape (args(i), caller));
      }
      if (cmd == "fuse")
      {
        BRepAlgoAPI_Fuse op;
        op.SetArguments (objects);
        op.SetTools (tools);
        out = todata (boolean (op, caller, "union"));
      }
      else
      {
        BRepAlgoAPI_Cut op;
        op.SetArguments (objects);
        op.SetTools (tools);
        out = todata (boolean (op, caller, "difference"));
      }
    }
    else if (cmd == "common")
    {
      TopoDS_Shape s = toshape (args(2), caller);
      for (int i = 3; i < args.length () && count (s, TopAbs_FACE) > 0; i++)
      {
        TopTools_ListOfShape objects, tools;
        objects.Append (s);
        tools.Append (toshape (args(i), caller));
        BRepAlgoAPI_Common op;
        op.SetArguments (objects);
        op.SetTools (tools);
        s = boolean (op, caller, "intersection");
      }
      out = todata (s);
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

    // Queries
    else if (cmd == "volume")
    {
      GProp_GProps p;
      BRepGProp::VolumeProperties (toshape (args(2), caller), p);
      out = p.Mass ();
    }
    else if (cmd == "area")
    {
      GProp_GProps p;
      BRepGProp::SurfaceProperties (toshape (args(2), caller), p);
      out = p.Mass ();
    }
    else if (cmd == "centroid")
    {
      GProp_GProps p;
      BRepGProp::VolumeProperties (toshape (args(2), caller), p);
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
                 args(4).string_value (), caller);
    }
    else if (cmd == "writestl")
    {
      writestl (toshape (args(2), caller), args(3).string_value (),
                args(4).double_value (),
                args(5).double_value () * M_PI / 180, caller);
    }
    else if (cmd == "readstep")
    {
      out = todata (readstep (args(2).string_value (), caller));
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

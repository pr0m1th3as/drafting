// Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
//
// This file is part of the drafting package for GNU Octave.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, see <http://www.gnu.org/licenses/>.

// The names of a shape's faces, which last through the operations that
// change the shape.  A face's name is the label given to the operation that
// made it and its role there, as "plate.zmax", with the copy the face is in
// for every array, or operation making several items, it went through.  A
// face keeps every name that reaches it, so a merged face holds several.
//
// The names travel in the shape's bytes, between Open CASCADE's own and the
// trailer (see shapebytes.h), in a format of this file's own.  They are kept
// by face number, in the order a map of the faces gives, and are stamped with
// the version of Open CASCADE that wrote them: only that version is known to
// read the faces back in the same order, so names read under another are
// refused.

#if ! defined (drafting_facenames_h)
#define drafting_facenames_h 1

#include <functional>
#include <set>
#include <string>
#include <vector>

#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Shape.hxx>

// One name of a face: its label, as dotted levels with the role last, and
// its copy in each array or several-item operation it went through, the
// first applied first
struct facename
{
  std::string label;
  std::vector<int> copy;

  bool operator < (const facename& other) const
  {
    return label != other.label ? label < other.label : copy < other.copy;
  }
};

// The names of every face of a shape, by face number from 0 in the order
// TopExp::MapShapes gives the faces.  STALE when the names were written by
// another version of Open CASCADE, or by another version of this format:
// none is kept then, and using one is an error.
struct facetable
{
  std::vector<std::set<facename>> faces;
  bool stale = false;

  // Whether no face has a name and the names are not stale, so that the
  // shape is written without them
  bool unnamed () const;
};

// The names T as they are written into a shape's bytes
std::string writenames (const facetable& t);

// The names written by writenames into BYTES, stale when another version of
// Open CASCADE or of the format wrote them, or when they cannot be read
facetable readnames (const std::string& bytes);

// The faces an operation modified the face it is given into, as the
// Modified method of Open CASCADE's builders gives them
typedef std::function<const TopTools_ListOfShape& (const TopoDS_Shape&)>
  modifiedfaces;

// The names of the faces of RESULT, carried by an operation from the faces
// of SOURCES, whose names are NAMES, one table for each source.  A face of
// RESULT that is a face of a source, or one the operation modified a face of
// a source into, as MODIFIED gives them, takes that face's names.  So a face
// split gives its names to every piece, faces merged give theirs all to the
// one face, and a face deleted gives none.  A face the operation generated
// takes none here: the operation names it from its own roles.  Stale names
// in any source leave RESULT's stale, and a table that does not have a
// face's count of entries for its source counts as stale.
facetable carrynames (const modifiedfaces& modified,
                      const std::vector<TopoDS_Shape>& sources,
                      const std::vector<facetable>& names,
                      const TopoDS_Shape& result);

#endif

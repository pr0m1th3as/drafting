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

// The names of a shape's faces: see facenames.h.
//
// They are written as unsigned 32-bit words, least significant byte first:
// the format, 1; the version of Open CASCADE that wrote them, as
// OCC_VERSION_HEX gives it; flags, 1 for stale; the number of faces; then
// for each face the number of its names, and for each name the length of its
// label, the label, the number of its copy levels and each copy.

#include "facenames.h"

#include <cstdint>

#include <Standard_Version.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

static const uint32_t namesformat = 1;
static const uint32_t stalebit = 1;

bool
facetable::unnamed () const
{
  if (stale)
  {
    return false;
  }
  for (const std::set<facename>& f : faces)
  {
    if (! f.empty ())
    {
      return false;
    }
  }
  return true;
}

// V appended to B in 4 bytes, least significant first
static void
put32 (std::string& b, uint32_t v)
{
  for (int i = 0; i < 4; i++)
  {
    b.push_back (static_cast<char> ((v >> (8 * i)) & 0xff));
  }
}

// The 4 bytes of B from AT as one number, AT moved past them; false when B
// ends first
static bool
get32 (const std::string& b, size_t& at, uint32_t& v)
{
  if (b.size () < 4 || at > b.size () - 4)
  {
    return false;
  }
  v = 0;
  for (int i = 0; i < 4; i++)
  {
    v |= static_cast<uint32_t> (static_cast<unsigned char> (b[at + i]))
         << (8 * i);
  }
  at += 4;
  return true;
}

std::string
writenames (const facetable& t)
{
  std::string b;
  put32 (b, namesformat);
  put32 (b, OCC_VERSION_HEX);
  put32 (b, t.stale ? stalebit : 0);
  if (t.stale)
  {
    put32 (b, 0);
    return b;
  }
  put32 (b, t.faces.size ());
  for (const std::set<facename>& f : t.faces)
  {
    put32 (b, f.size ());
    for (const facename& n : f)
    {
      put32 (b, n.label.size ());
      b += n.label;
      put32 (b, n.copy.size ());
      for (int c : n.copy)
      {
        put32 (b, static_cast<uint32_t> (c));
      }
    }
  }
  return b;
}

facetable
readnames (const std::string& b)
{
  facetable t;
  facetable refused;
  refused.stale = true;
  size_t at = 0;
  uint32_t format, version, flags, nfaces;
  if (! get32 (b, at, format) || ! get32 (b, at, version)
      || ! get32 (b, at, flags) || ! get32 (b, at, nfaces)
      || format != namesformat || version != OCC_VERSION_HEX
      || (flags & stalebit))
  {
    return refused;
  }
  // Every face takes at least a word, so a count beyond what is left is
  // damage, and is not used to reserve memory
  if (nfaces > (b.size () - at) / 4)
  {
    return refused;
  }
  t.faces.resize (nfaces);
  for (uint32_t i = 0; i < nfaces; i++)
  {
    uint32_t k;
    if (! get32 (b, at, k))
    {
      return refused;
    }
    for (uint32_t j = 0; j < k; j++)
    {
      facename n;
      uint32_t len, ncopy;
      if (! get32 (b, at, len) || len > b.size () - at)
      {
        return refused;
      }
      n.label = b.substr (at, len);
      at += len;
      if (! get32 (b, at, ncopy) || ncopy > (b.size () - at) / 4)
      {
        return refused;
      }
      for (uint32_t c = 0; c < ncopy; c++)
      {
        uint32_t v;
        get32 (b, at, v);
        n.copy.push_back (static_cast<int> (v));
      }
      t.faces[i].insert (n);
    }
  }
  if (at != b.size ())
  {
    return refused;
  }
  return t;
}

facetable
carrynames (const modifiedfaces& modified,
            const std::vector<TopoDS_Shape>& sources,
            const std::vector<facetable>& names,
            const TopoDS_Shape& result)
{
  facetable r;
  bool named = false;
  for (const facetable& t : names)
  {
    if (t.stale)
    {
      r.stale = true;
      return r;
    }
    named = named || ! t.unnamed ();
  }
  if (! named)
  {
    return r;
  }
  TopTools_IndexedMapOfShape out;
  TopExp::MapShapes (result, TopAbs_FACE, out);
  r.faces.resize (out.Extent ());
  for (size_t k = 0; k < sources.size () && k < names.size (); k++)
  {
    if (names[k].unnamed ())
    {
      continue;
    }
    TopTools_IndexedMapOfShape in;
    TopExp::MapShapes (sources[k], TopAbs_FACE, in);
    if (static_cast<size_t> (in.Extent ()) != names[k].faces.size ())
    {
      facetable refused;
      refused.stale = true;
      return refused;
    }
    for (int i = 1; i <= in.Extent (); i++)
    {
      const std::set<facename>& own = names[k].faces[i-1];
      if (own.empty ())
      {
        continue;
      }
      auto give = [&] (const TopoDS_Shape& g)
      {
        const int j = out.FindIndex (g);
        if (j > 0)
        {
          r.faces[j-1].insert (own.begin (), own.end ());
        }
      };
      give (in (i));
      for (const TopoDS_Shape& g : modified (in (i)))
      {
        give (g);
      }
    }
  }
  return r;
}

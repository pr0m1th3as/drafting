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

// The bytes of a shape as they cross into Octave: Open CASCADE's binary
// format, then a trailer of 16 bytes, a 64-bit FNV-1a hash of the bytes
// before it and a tag.  Open CASCADE's reader checks nothing and crashes on
// damaged bytes, so bytes whose trailer does not match are never given to it.
// A shape whose faces have names carries them between its own bytes and the
// trailer, followed by their length in 8 bytes, under a tag of its own; the
// hash covers them too.  A shape without names is written as before.

#if ! defined (drafting_shapebytes_h)
#define drafting_shapebytes_h 1

#include <cstdint>
#include <string>

static const char shapetag[] = "drftsum1";
static const char namedtag[] = "drftsum2";
static const size_t shapetrailer = 16;

static inline uint64_t
shapehash (const char *p, size_t n)
{
  uint64_t h = 14695981039346656037ULL;
  for (size_t i = 0; i < n; i++)
  {
    h ^= static_cast<unsigned char> (p[i]);
    h *= 1099511628211ULL;
  }
  return h;
}

// V appended to BYTES in 8 bytes, least significant first
static inline void
putword (std::string& bytes, uint64_t v)
{
  for (int i = 0; i < 8; i++)
  {
    bytes.push_back (static_cast<char> ((v >> (8 * i)) & 0xff));
  }
}

// The 8 bytes of BYTES from AT as one number, least significant first
static inline uint64_t
getword (const std::string& bytes, size_t at)
{
  uint64_t v = 0;
  for (int i = 0; i < 8; i++)
  {
    v |= static_cast<uint64_t> (static_cast<unsigned char> (bytes[at + i]))
         << (8 * i);
  }
  return v;
}

// BYTES with the trailer appended, and before it NAMES, the names of the
// faces as facenames.cc writes them, when there are any
static inline void
sealshape (std::string& bytes, const std::string& names = std::string ())
{
  if (! names.empty ())
  {
    bytes += names;
    putword (bytes, names.size ());
  }
  putword (bytes, shapehash (bytes.data (), bytes.size ()));
  bytes.append (names.empty () ? shapetag : namedtag, 8);
}

// Whether BYTES end with a trailer that matches them.  If so the trailer is
// removed, and with it the names of the faces into NAMES, left empty for a
// shape that has none.
static inline bool
unsealshape (std::string& bytes, std::string& names)
{
  names.clear ();
  const size_t n = bytes.size ();
  if (n < shapetrailer)
  {
    return false;
  }
  const bool named = bytes.compare (n - 8, 8, namedtag) == 0;
  if (! named && bytes.compare (n - 8, 8, shapetag) != 0)
  {
    return false;
  }
  size_t m = n - shapetrailer;
  if (getword (bytes, m) != shapehash (bytes.data (), m))
  {
    return false;
  }
  if (named)
  {
    const uint64_t k = (m < 8 ? 0 : getword (bytes, m - 8));
    if (m < 8 || k == 0 || k > m - 8)
    {
      return false;
    }
    names = bytes.substr (m - 8 - k, k);
    m -= 8 + k;
  }
  bytes.resize (m);
  return true;
}

// As above, for a reader that does not use the names
static inline bool
unsealshape (std::string& bytes)
{
  std::string names;
  return unsealshape (bytes, names);
}

#endif

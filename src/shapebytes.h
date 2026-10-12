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

#if ! defined (drafting_shapebytes_h)
#define drafting_shapebytes_h 1

#include <cstdint>
#include <string>

static const char shapetag[] = "drftsum1";
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

// BYTES with the trailer appended
static inline void
sealshape (std::string& bytes)
{
  const uint64_t h = shapehash (bytes.data (), bytes.size ());
  for (int i = 0; i < 8; i++)
  {
    bytes.push_back (static_cast<char> ((h >> (8 * i)) & 0xff));
  }
  bytes.append (shapetag, 8);
}

// Whether BYTES end with a trailer that matches them, which is then removed
static inline bool
unsealshape (std::string& bytes)
{
  const size_t n = bytes.size ();
  if (n < shapetrailer || bytes.compare (n - 8, 8, shapetag) != 0)
  {
    return false;
  }
  const size_t m = n - shapetrailer;
  uint64_t h = 0;
  for (int i = 0; i < 8; i++)
  {
    h |= static_cast<uint64_t> (static_cast<unsigned char> (bytes[m + i]))
         << (8 * i);
  }
  if (h != shapehash (bytes.data (), m))
  {
    return false;
  }
  bytes.resize (m);
  return true;
}

#endif

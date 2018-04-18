/*
ShaderX Noise Library.

This library is a modified version of the noise library found in
Open Shading Language:
github.com/imageworks/OpenShadingLanguage/blob/master/src/include/OSL/oslnoise.h

It contains the subset of noise types needed to implement the MaterialX
standard library. The modifications are mainly conversions from C++ to GLSL.
Produced results should be identical to the OSL noise functions.

Original copyright notice:
------------------------------------------------------------------------
Copyright (c) 2009-2010 Sony Pictures Imageworks Inc., et al.
All Rights Reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of Sony Pictures Imageworks nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------
*/

float sx_select(bool b, float t, float f)
{
    return b ? t : f;
}

float sx_negate_if(float val, bool b)
{
    return b ? -val : val;
}

int sx_floor(float x)
{
    // return the greatest integer <= x
    return x < 0.0 ? int(x) - 1 : int(x);
}

// return sx_floor as well as the fractional remainder
float sx_floorfrac(float x, out int i)
{
    i = sx_floor(x);
    return x - i;
}

float sx_bilerp(float v0, float v1, float v2, float v3, float s, float t)
{
    float s1 = 1.0 - s;
    return (1.0 - t) * (v0*s1 + v1*s) + t * (v2*s1 + v3*s);
}
vec3 sx_bilerp(vec3 v0, vec3 v1, vec3 v2, vec3 v3, float s, float t)
{
    float s1 = 1.0 - s;
    return (1.0 - t) * (v0*s1 + v1*s) + t * (v2*s1 + v3*s);
}
float sx_trilerp(float v0, float v1, float v2, float v3, float v4, float v5, float v6, float v7, float s, float t, float r)
{
    float s1 = 1.0 - s;
    float t1 = 1.0 - t;
    float r1 = 1.0 - r;
    return (r1*(t1*(v0*s1 + v1*s) + t*(v2*s1 + v3*s)) +
            r*(t1*(v4*s1 + v5*s) + t*(v6*s1 + v7*s)));
}
vec3 sx_trilerp(vec3 v0, vec3 v1, vec3 v2, vec3 v3, vec3 v4, vec3 v5, vec3 v6, vec3 v7, float s, float t, float r)
{
    float s1 = 1.0 - s;
    float t1 = 1.0 - t;
    float r1 = 1.0 - r;
    return (r1*(t1*(v0*s1 + v1*s) + t*(v2*s1 + v3*s)) +
            r*(t1*(v4*s1 + v5*s) + t*(v6*s1 + v7*s)));
}

// 2 and 3 dimensional gradient functions - perform a dot product against a
// randomly chosen vector. Note that the gradient vector is not normalized, but
// this only affects the overal "scale" of the result, so we simply account for
// the scale by multiplying in the corresponding "perlin" function.
float sx_gradient(uint hash, float x, float y)
{
    // 8 possible directions (+-1,+-2) and (+-2,+-1)
    uint h = hash & 7;
    float u = sx_select(h<4, x, y);
    float v = 2.0 * sx_select(h<4, y, x);
    // compute the dot product with (x,y).
    return sx_negate_if(u, bool(h&1)) + sx_negate_if(v, bool(h&2));
}
float sx_gradient(uint hash, float x, float y, float z)
{
    // use vectors pointing to the edges of the cube
    uint h = hash & 15;
    float u = sx_select(h<8, x, y);
    float v = sx_select(h<4, y, sx_select((h==12)||(h==14), x, z));
    return sx_negate_if(u, bool(h&1)) + sx_negate_if(v, bool(h&2));
}
vec3 sx_gradient(uvec3 hash, float x, float y)
{
    return vec3(sx_gradient(hash.x, x, y), sx_gradient(hash.y, x, y), sx_gradient(hash.z, x, y));
}
vec3 sx_gradient(uvec3 hash, float x, float y, float z)
{
    return vec3(sx_gradient(hash.x, x, y, z), sx_gradient(hash.y, x, y, z), sx_gradient(hash.z, x, y, z));
}
// Scaling factors to normalize the result of gradients above.
// These factors were experimentally calculated to be:
//    2D:   0.6616
//    3D:   0.9820
float sx_gradient_scale2d(float v) { return 0.6616 * v; }
float sx_gradient_scale3d(float v) { return 0.9820 * v; }
vec3 sx_gradient_scale2d(vec3 v) { return 0.6616 * v; }
vec3 sx_gradient_scale3d(vec3 v) { return 0.9820 * v; }

/// Bitwise circular rotation left by k bits (for 32 bit unsigned integers)
uint sx_rotl32(uint x, int k)
{
    return (x<<k) | (x>>(32-k));
}

// Mix up and combine the bits of a, b, and c (doesn't change them, but
// returns a hash of those three original values).
uint sx_bjfinal(uint a, uint b, uint c)
{
    c ^= b; c -= sx_rotl32(b,14);
    a ^= c; a -= sx_rotl32(c,11);
    b ^= a; b -= sx_rotl32(a,25);
    c ^= b; c -= sx_rotl32(b,16);
    a ^= c; a -= sx_rotl32(c,4);
    b ^= a; b -= sx_rotl32(a,14);
    c ^= b; c -= sx_rotl32(b,24);
    return c;
}

// Convert a 32 bit integer into a floating point number in [0,1]
float sx_bits_to_01(uint bits)
{
    return float(bits) / float(uint(0xffffffff));
}

float sx_fade(float t)
{
   return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

uint sx_hash_int(int x, int y)
{
    uint a, b, c;
    uint len = 2;
    a = b = c = 0xdeadbeef + (len << 2) + 13;
    a += x;
    b += y;
    c = sx_bjfinal(a, b, c);
    return c;
}

uint sx_hash_int(int x, int y, int z)
{
    uint a, b, c;
    uint len = 3;
    a = b = c = 0xdeadbeef + (len << 2) + 13;
    a += x;
    b += y;
    c += z;
    c = sx_bjfinal(a, b, c);
    return c;
}

uvec3 sx_hash_vec3(int x, int y)
{
    uint h = sx_hash_int(x, y);
    // we only need the low-order bits to be random, so split out
    // the 32 bit result into 3 parts for each channel
    uvec3 result;
    result.x = (h      ) & 0xFF;
    result.y = (h >> 8 ) & 0xFF;
    result.z = (h >> 16) & 0xFF;
    return result;
}

uvec3 sx_hash_vec3(int x, int y, int z)
{
    uint h = sx_hash_int(x, y, z);
    // we only need the low-order bits to be random, so split out
    // the 32 bit result into 3 parts for each channel
    uvec3 result;
    result.x = (h      ) & 0xFF;
    result.y = (h >> 8 ) & 0xFF;
    result.z = (h >> 16) & 0xFF;
    return result;
}

float sx_perlin_noise_float(vec2 p)
{
    int X, Y; 
    float fx = sx_floorfrac(p.x, X);
    float fy = sx_floorfrac(p.y, Y);
    float u = sx_fade(fx);
    float v = sx_fade(fy);
    float result = sx_bilerp(
        sx_gradient(sx_hash_int(X  , Y  ), fx    , fy     ),
        sx_gradient(sx_hash_int(X+1, Y  ), fx-1.0, fy     ),
        sx_gradient(sx_hash_int(X  , Y+1), fx    , fy-1.0),
        sx_gradient(sx_hash_int(X+1, Y+1), fx-1.0, fy-1.0), 
        u, v);
    return sx_gradient_scale2d(result);
}

float sx_perlin_noise_float(vec3 p)
{
    int X, Y, Z; 
    float fx = sx_floorfrac(p.x, X);
    float fy = sx_floorfrac(p.y, Y);
    float fz = sx_floorfrac(p.z, Z);
    float u = sx_fade(fx);
    float v = sx_fade(fy);
    float w = sx_fade(fz);
    float result = sx_trilerp(
        sx_gradient(sx_hash_int(X  , Y  , Z  ), fx    , fy    , fz     ),
        sx_gradient(sx_hash_int(X+1, Y  , Z  ), fx-1.0, fy    , fz     ),
        sx_gradient(sx_hash_int(X  , Y+1, Z  ), fx    , fy-1.0, fz     ),
        sx_gradient(sx_hash_int(X+1, Y+1, Z  ), fx-1.0, fy-1.0, fz     ),
        sx_gradient(sx_hash_int(X  , Y  , Z+1), fx    , fy    , fz-1.0),
        sx_gradient(sx_hash_int(X+1, Y  , Z+1), fx-1.0, fy    , fz-1.0),
        sx_gradient(sx_hash_int(X  , Y+1, Z+1), fx    , fy-1.0, fz-1.0),
        sx_gradient(sx_hash_int(X+1, Y+1, Z+1), fx-1.0, fy-1.0, fz-1.0),
        u, v, w);
    return sx_gradient_scale3d(result);
}

vec3 sx_perlin_noise_vec3(vec2 p)
{
    int X, Y; 
    float fx = sx_floorfrac(p.x, X);
    float fy = sx_floorfrac(p.y, Y);
    float u = sx_fade(fx);
    float v = sx_fade(fy);
    vec3 result = sx_bilerp(
        sx_gradient(sx_hash_vec3(X  , Y  ), fx    , fy     ),
        sx_gradient(sx_hash_vec3(X+1, Y  ), fx-1.0, fy     ),
        sx_gradient(sx_hash_vec3(X  , Y+1), fx    , fy-1.0),
        sx_gradient(sx_hash_vec3(X+1, Y+1), fx-1.0, fy-1.0), 
        u, v);
    return sx_gradient_scale2d(result);
}

vec3 sx_perlin_noise_vec3(vec3 p)
{
    int X, Y, Z; 
    float fx = sx_floorfrac(p.x, X);
    float fy = sx_floorfrac(p.y, Y);
    float fz = sx_floorfrac(p.z, Z);
    float u = sx_fade(fx);
    float v = sx_fade(fy);
    float w = sx_fade(fz);
    vec3 result = sx_trilerp(
        sx_gradient(sx_hash_vec3(X  , Y  , Z  ), fx    , fy    , fz     ),
        sx_gradient(sx_hash_vec3(X+1, Y  , Z  ), fx-1.0, fy    , fz     ),
        sx_gradient(sx_hash_vec3(X  , Y+1, Z  ), fx    , fy-1.0, fz     ),
        sx_gradient(sx_hash_vec3(X+1, Y+1, Z  ), fx-1.0, fy-1.0, fz     ),
        sx_gradient(sx_hash_vec3(X  , Y  , Z+1), fx    , fy    , fz-1.0),
        sx_gradient(sx_hash_vec3(X+1, Y  , Z+1), fx-1.0, fy    , fz-1.0),
        sx_gradient(sx_hash_vec3(X  , Y+1, Z+1), fx    , fy-1.0, fz-1.0),
        sx_gradient(sx_hash_vec3(X+1, Y+1, Z+1), fx-1.0, fy-1.0, fz-1.0),
        u, v, w);
    return sx_gradient_scale3d(result);
}

float sx_cell_noise_float(vec2 p)
{
    int ix = sx_floor(p.x);
    int iy = sx_floor(p.y);
    return sx_bits_to_01(sx_hash_int(ix, iy));
}

float sx_cell_noise_float(vec3 p)
{
    int ix = sx_floor(p.x);
    int iy = sx_floor(p.y);
    int iz = sx_floor(p.z);
    return sx_bits_to_01(sx_hash_int(ix, iy, iz));
}

float sx_fractal_noice_float(vec3 p, int octaves, float lacunarity, float diminish)
{
    float result = 0.0;
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * sx_perlin_noise_float(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec3 sx_fractal_noice_vec3(vec3 p, int octaves, float lacunarity, float diminish)
{
    vec3 result = vec3(0.0);
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * sx_perlin_noise_vec3(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}
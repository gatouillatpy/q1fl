#ifndef FLOAT4_H
#define FLOAT4_H

inline static float rsqrtf( float x )
{
	return 1.0f / sqrtf(x);
}

typedef struct
{
	float x;
	float y;
	float z;
	float w;
} float4;

inline static float4 make_float4( float x, float y, float z, float w )
{
	float4 t; t.x = x; t.y = y; t.z = z; t.w = w; return t;
}

inline static float dot( float4 a, float4 b )
{ 
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

inline static float length( float4 r )
{
	return sqrtf( dot( r, r ) );
}

inline static float4 normalize( float4 v )
{
	float inv_len = rsqrtf( dot( v, v ) );

	return make_float4( v.x * inv_len, v.y * inv_len, v.z * inv_len, v.w * inv_len );
}

#endif

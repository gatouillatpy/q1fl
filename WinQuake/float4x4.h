#ifndef FLOAT4X4_H
#define FLOAT4X4_H

#include "float4.h"

typedef struct
{
	float4 r0;
	float4 r1;
	float4 r2;
	float4 r3;
} float4x4;

inline static void matrixClone( float4x4* r, float4x4 m )
{
	r->r0 = make_float4( m.r0.x, m.r0.y, m.r0.z, m.r0.w );
	r->r1 = make_float4( m.r1.x, m.r1.y, m.r1.z, m.r1.w );
	r->r2 = make_float4( m.r2.x, m.r2.y, m.r2.z, m.r2.w );
	r->r3 = make_float4( m.r3.x, m.r3.y, m.r3.z, m.r3.w );
}

inline static void matrixTranspose( float4x4* r, float4x4 m )
{
	r->r0 = make_float4( m.r0.x, m.r1.x, m.r2.x, m.r3.x );
	r->r1 = make_float4( m.r0.y, m.r1.y, m.r2.y, m.r3.y );
	r->r2 = make_float4( m.r0.z, m.r1.z, m.r2.z, m.r3.z );
	r->r3 = make_float4( m.r0.w, m.r1.w, m.r2.w, m.r3.w );
}

inline static void matrixMultiply( float4x4* r, float4x4 a, float4x4 b )
{
	float4x4 t;
	
	matrixTranspose( &t, b );

	r->r0.x = dot( a.r0, t.r0 );
	r->r0.y = dot( a.r0, t.r1 );
	r->r0.z = dot( a.r0, t.r2 );
	r->r0.w = dot( a.r0, t.r3 );

	r->r1.x = dot( a.r1, t.r0 );
	r->r1.y = dot( a.r1, t.r1 );
	r->r1.z = dot( a.r1, t.r2 );
	r->r1.w = dot( a.r1, t.r3 );

	r->r2.x = dot( a.r2, t.r0 );
	r->r2.y = dot( a.r2, t.r1 );
	r->r2.z = dot( a.r2, t.r2 );
	r->r2.w = dot( a.r2, t.r3 );

	r->r3.x = dot( a.r3, t.r0 );
	r->r3.y = dot( a.r3, t.r1 );
	r->r3.z = dot( a.r3, t.r2 );
	r->r3.w = dot( a.r3, t.r3 );
}

inline static void matrixIdentity( float4x4* r )
{
	r->r0 = make_float4( 1.0f, 0.0f, 0.0f, 0.0f );
	r->r1 = make_float4( 0.0f, 1.0f, 0.0f, 0.0f );
	r->r2 = make_float4( 0.0f, 0.0f, 1.0f, 0.0f );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

inline static void matrixTranslation( float4x4* r, float x, float y, float z )
{
	r->r0 = make_float4( 1.0f, 0.0f, 0.0f,    x );
	r->r1 = make_float4( 0.0f, 1.0f, 0.0f,    y );
	r->r2 = make_float4( 0.0f, 0.0f, 1.0f,    z );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

inline static void matrixRotationX( float4x4* r, float angle )
{
	float u = cosf( angle );
	float v = sinf( angle );

	r->r0 = make_float4( 1.0f, 0.0f, 0.0f, 0.0f );
	r->r1 = make_float4( 0.0f,    u,   -v, 0.0f );
	r->r2 = make_float4( 0.0f,    v,    u, 0.0f );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

inline static void matrixRotationY( float4x4* r, float angle )
{
	float u = cosf( angle );
	float v = sinf( angle );

	r->r0 = make_float4(    u, 0.0f,    v, 0.0f );
	r->r1 = make_float4( 0.0f, 1.0f, 0.0f, 0.0f );
	r->r2 = make_float4(   -v, 0.0f,    u, 0.0f );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

inline static void matrixRotationZ( float4x4* r, float angle )
{
	float u = cosf( angle );
	float v = sinf( angle );

	r->r0 = make_float4(    u,   -v, 0.0f, 0.0f );
	r->r1 = make_float4(    v,    u, 0.0f, 0.0f );
	r->r2 = make_float4( 0.0f, 0.0f, 1.0f, 0.0f );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

inline static void matrixRotationAxis( float4x4* r, float angle, float x, float y, float z )
{
	float u = cosf( angle );
	float v = sinf( angle );
	float w = 1.0f - u;

	float4 n = normalize( make_float4( x, y, z, 0.0 ) );

	r->r0.x = w * n.x * n.x + u;
	r->r0.y = w * n.x * n.y - v * n.z;
	r->r0.z = w * n.x * n.z + v * n.y;
	r->r0.w = 0.0f;

	r->r1.x = w * n.y * n.x + v * n.z;
	r->r1.y = w * n.y * n.y + u;
	r->r1.z = w * n.y * n.z - v * n.x;
	r->r1.w = 0.0f;

	r->r2.x = w * n.z * n.x - v * n.y;
	r->r2.y = w * n.z * n.y + v * n.x;
	r->r2.z = w * n.z * n.z + u;
	r->r2.w = 0.0f;

	r->r3.x = 0.0f;
	r->r3.y = 0.0f;
	r->r3.z = 0.0f;
	r->r3.w = 1.0f;
}

inline static void matrixScale( float4x4* r, float x, float y, float z )
{
	r->r0 = make_float4(    x, 0.0f, 0.0f, 0.0f );
	r->r1 = make_float4( 0.0f,    y, 0.0f, 0.0f );
	r->r2 = make_float4( 0.0f, 0.0f,    z, 0.0f );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

inline static void matrixFrustum( float4x4* r, float left, float right, float bottom, float top, float nearVal, float farVal )
{
	float a = (right + left) / (right - left);
	float b = (top + bottom) / (top - bottom);
	float c = -(farVal + nearVal) / (farVal - nearVal);
	float d = -2 * farVal * nearVal / (farVal - nearVal);
	float e = 2 * nearVal / (right - left);
	float f = 2 * nearVal / (top - bottom);
	
	r->r0 = make_float4(    e, 0.0f,     a, 0.0f );
	r->r1 = make_float4( 0.0f,    f,     b, 0.0f );
	r->r2 = make_float4( 0.0f, 0.0f,     c,    d );
	r->r3 = make_float4( 0.0f, 0.0f, -1.0f, 0.0f );
}
		
inline static void matrixOrtho( float4x4* r, float left, float right, float bottom, float top, float nearVal, float farVal )
{
	float a = 2 / (right - left);
	float b = 2 / (top - bottom);
	float c = -2 / (farVal - nearVal);
	float d = -(right + left) / (right - left);
	float e = -(top + bottom) / (top - bottom);
	float f = -(farVal + nearVal) / (farVal - nearVal);
	
	r->r0 = make_float4(    a, 0.0f, 0.0f,    d );
	r->r1 = make_float4( 0.0f,    b, 0.0f,    e );
	r->r2 = make_float4( 0.0f, 0.0f,    c,    f );
	r->r3 = make_float4( 0.0f, 0.0f, 0.0f, 1.0f );
}

#endif

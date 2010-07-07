
#include "float4.h"
#include "float4x4.h"

#ifdef FLASH

/***************************************************/
/** GLOBALS                                        */
/***************************************************/

AS3_Val _renderer;

unsigned masm_data[1048576];
unsigned* masm_ptr;

float4x4 matrix_stack_data[20];
float4x4* matrix_stack_ptr;

float4x4 world_matrix;
float4x4 projection_matrix;
float4x4* matrix;

float vertices[65536];
float colors[65536];
float texcoords[32768];

int vertex_count;
int index_count;

float color_r;
float color_g;
float color_b;
float color_a;

float texcoord_u;
float texcoord_v;

float sum_vertex_x;
float sum_vertex_y;
float sum_vertex_z;
float sum_vertex_w;

float sum_color_r;
float sum_color_g;
float sum_color_b;
float sum_color_a;

float sum_texcoord_u;
float sum_texcoord_v;

int use_texturing;

int texture_id;

int polygon_type;

int need_draw;

int vertex_offset;

/***************************************************/
/** PROTOTYPES                                     */
/***************************************************/

void molehill_clear( float r, float g, float b, float a, float depth, int stencil );
void molehill_flush();

void molehill_begin( int type );
void molehill_setVertex( float x, float y, float z, float w );
void molehill_setColor( float r, float g, float b, float a );
void molehill_setTexcoord( float u, float v );
void molehill_end();

void molehill_draw();

void molehill_bindTexture( int id );
void molehill_uploadTexture( int channels, int width, int height, void* data );

void molehill_setDepthTest( int writeDepth, int passCompare );
void molehill_setBlending( int srcBlend, int destBlend );
void molehill_setViewport( int left, int top, int width, int height );
void molehill_setCulling( int cullAway );

void molehill_identity();
void molehill_translate( float x, float y, float z );
void molehill_rotate( float angle, float x, float y, float z );
void molehill_scale( float x, float y, float z );
void molehill_frustum( float left, float right, float bottom, float top, float nearVal, float farVal );
void molehill_ortho( float left, float right, float bottom, float top, float nearVal, float farVal );
void molehill_push();
void molehill_pop();
void molehill_setMatrixType( int type );
void molehill_getMatrix( float* data );
void molehill_setMatrix( float* data );

/***************************************************/
/** INIT                                           */
/***************************************************/

void molehill_init()
{
	masm_ptr = masm_data;
	
	matrix_stack_ptr = matrix_stack_data;
}

/***************************************************/
/** CONTROL                                        */
/***************************************************/

#define MOLEHILL_BEGIN					0x00010000
#define MOLEHILL_END					0x00020000
	
inline static void molehill_start()
{
	masm_ptr = masm_data;
	
	*masm_ptr = MOLEHILL_BEGIN;
	masm_ptr++;
	
	need_draw = 0;
	
	vertex_offset = 0;
}

inline static void molehill_stop()
{
	*masm_ptr = MOLEHILL_END;
	masm_ptr++;

	AS3_Val params = AS3_Array( "AS3ValType", AS3_Ptr(masm_data) );
	AS3_CallS( "execute", _renderer, params );
}

#endif
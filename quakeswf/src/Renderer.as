package  
{
	import flash.display.Bitmap;
	import flash.display.Bitmap3D;
	import flash.display.BitmapData;
	import flash.display.Program3D;
	import flash.display.IndexBuffer3D;
	import flash.display.Texture3D;
	import flash.display.VertexBuffer3D;
	import flash.events.TimerEvent;
	import flash.geom.Matrix3D;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.Timer;
	import flash.utils.getTimer;

	/**
	 * ...
	 * @author 12
	 */
	public class Renderer extends Bitmap3D
	{
		private const MOLEHILL_BEGIN : uint						= 0x00010000;
		private const MOLEHILL_END : uint						= 0x00020000;

		private const MOLEHILL_CLEAR : uint						= 0x00110000;
		private const MOLEHILL_FLUSH : uint						= 0x00120000;

		private const MOLEHILL_BIND : uint						= 0x00210000;

		private const MOLEHILL_SET_DEPTHTEST : uint				= 0x00310000;
		private const MOLEHILL_SET_BLENDING : uint				= 0x00320000;
		private const MOLEHILL_SET_VIEWPORT : uint				= 0x00330000;
		private const MOLEHILL_SET_CULLING : uint				= 0x00340000;

		private const MOLEHILL_MATRIX : uint					= 0x00410000;
		private const MOLEHILL_VERTICES : uint					= 0x00420000;
		private const MOLEHILL_INDICES : uint					= 0x00430000;

		private const MOLEHILL_DRAW : uint						= 0x00510000;

		private const MOLEHILL_TRIANGLE_LIST : uint				= 0x00000001;
		private const MOLEHILL_TRIANGLE_STRIP : uint			= 0x00000002;
		private const MOLEHILL_TRIANGLE_FAN : uint				= 0x00000003;
		private const MOLEHILL_QUAD_LIST : uint					= 0x00000011;
		private const MOLEHILL_POLYGON : uint					= 0x00000024;

		private const MOLEHILL_IGNORE : uint					= 0x00000000;
		private const MOLEHILL_WRITE : uint						= 0x00000100;

		private const MOLEHILL_ALWAYS : uint					= 0x00000001;
		private const MOLEHILL_LESS_OR_EQUAL : uint				= 0x00000002;

		private const MOLEHILL_SRC_ONE : uint					= 0x00000100;
		private const MOLEHILL_SRC_ZERO : uint					= 0x00000200;
		private const MOLEHILL_SRC_ALPHA : uint					= 0x00000300;
		private const MOLEHILL_DST_ONE : uint					= 0x00000001;
		private const MOLEHILL_DST_ZERO : uint					= 0x00000002;
		private const MOLEHILL_ONE_MINUS_SRC_ALPHA : uint		= 0x00000003;
		private const MOLEHILL_ONE_MINUS_SRC_COLOR : uint		= 0x00000004;

		private const MOLEHILL_NONE : uint						= 0x00000001;
		private const MOLEHILL_FRONT : uint						= 0x00000002;
		private const MOLEHILL_BACK : uint						= 0x00000003;

		private var sp0 : Program3D; 
		private var sp1 : Program3D; 
		private var ib : IndexBuffer3D; 
		private var vb0 : VertexBuffer3D; 
		private var vb1 : VertexBuffer3D; 
		
		private var vertex_count : int;
		private var index_count : int;
		
		private var vertex_offset : int;
		private var index_offset : int;
		
		private var matrix : Matrix3D;
		
		private var ram : ByteArray;
		
		private var textures : Array;
		private var tid : int;

		private var matrix_values : Vector.<Number>;

		private var vertices : Vector.<Number>;
		private var indices : Vector.<uint>;
		
		private var use_texturing : Boolean;
		
		public var enabled : Boolean;

		public function Renderer( ram : ByteArray, rendermode : String = "DIRECTX9" ) 
		{
			super( rendermode );
			
			this.ram = ram;
			
			this.enabled = true;

			init(); 
		}
		
		private var old_time : int;
		
		private function getTimeStamp() : String
		{
			var new_time : int = getTimer();
			
			var delta : int = new_time - old_time;
			
			old_time = new_time;
			
			return "[" + new_time + " | " + delta + " ms]";
		}
		
		public function init() : void 
		{
			getTimeStamp();
			
			setupBackbuffer( 640, 480, 0, true );
			
			matrix_values = new Vector.<Number>();
			
			vertices = new Vector.<Number>();
			indices = new Vector.<uint>();
			
			vertex_count = 0;
			index_count = 0;

			vertex_offset = 0;
			index_offset = 0;

			textures = new Array();
			tid = 0;
			
			x = 0;
			y = 0;
			
			var vs0 : AGALMiniAssembler = new AGALMiniAssembler();
			vs0.Assemble
			(
				"VERTEX",
				"dp4 op.x, va0, vc0     \n" +
				"dp4 op.y, va0, vc1     \n" +
				"dp4 op.z, va0, vc2     \n" +
				"dp4 op.w, va0, vc3     \n" +
				"mov v0, va1.xyzw       \n" +
				"mov v1, va2.xyzw       \n"
			);
			
			var ps0 : AGALMiniAssembler = new AGALMiniAssembler(); 
			ps0.Assemble
			(
				"FRAGMENT",		
				"mov ft1, v1						\n" +
				"tex ft2, ft1, fs1 [2d,linear,wrap]	\n" +
				"mul ft0, ft2, v0					\n" +
				"mov oc, ft0						\n"
			);
			
			sp0 = createProgram();
			sp0.upload( vs0.agalcode, ps0.agalcode );

			var vs1 : AGALMiniAssembler = new AGALMiniAssembler();
			vs1.Assemble
			(
				"VERTEX",
				"dp4 op.x, va0, vc0     \n" +
				"dp4 op.y, va0, vc1     \n" +
				"dp4 op.z, va0, vc2     \n" +
				"dp4 op.w, va0, vc3     \n" +
				"mov v0, va1.xyzw       \n"
			);
			
			var ps1 : AGALMiniAssembler = new AGALMiniAssembler(); 
			ps1.Assemble
			(
				"FRAGMENT",		
				"mov oc, v0			\n"
			);
			
			sp1 = createProgram();
			sp1.upload( vs1.agalcode, ps1.agalcode );
			
			ib = createIndexBuffer( 4096 );
			
			vb0 = createVertexBuffer( 16384, 10 ); // vertex + color + texcoord
			vb1 = createVertexBuffer( 16384, 8 ); // vertex + color
		}
		
		public function execute( data_ptr : uint ) : void
		{
			trace( getTimeStamp() + " begin execute( " + data_ptr + " )" );
			
			ram.position = data_ptr;
			
			var last_opcode : uint;
			var opcode : uint;
			var count : uint = 0;
			
			if ( ( opcode = ram.readUnsignedInt() ) == MOLEHILL_BEGIN )
			{
				while ( ( opcode = ram.readUnsignedInt() ) != MOLEHILL_END )
				{
					count++;
					
					if ( opcode == MOLEHILL_CLEAR )
					{
						var red : Number = ram.readFloat();
						var green : Number = ram.readFloat();
						var blue : Number = ram.readFloat();
						var alpha : Number = ram.readFloat();
						var depth : Number = ram.readFloat();
						var stencil : int = ram.readInt();
						
						clear( red, green, blue, alpha, depth, stencil );
					}
					else if ( opcode == MOLEHILL_FLUSH )
					{
						flush();
					}
					else if ( opcode == MOLEHILL_MATRIX )
					{
						for ( var k : int = 0 ; k < 16 ; k++ )
							matrix_values[k] = ram.readFloat();
						
						matrix = new Matrix3D( matrix_values );
						matrix.transpose();
					}
					else if ( opcode == MOLEHILL_VERTICES + 0x0A )
					{
						use_texturing = true;
						
						vertex_count += ram.readInt();
						
						for ( var i : int = vertex_offset * 10 ; i < vertex_count * 10 ; i++ )
							vertices[i] = ram.readFloat();
						
						vertex_offset = vertex_count;
					}
					else if ( opcode == MOLEHILL_VERTICES + 0x08 )
					{
						use_texturing = false;

						vertex_count += ram.readInt();
						
						for ( var j : int = vertex_offset * 8 ; j < vertex_count * 8 ; j++ )
							vertices[j] = ram.readFloat();
						
						vertex_offset = vertex_count;
					}
					else if ( opcode == MOLEHILL_INDICES )
					{
						index_count += ram.readInt();
						
						for ( var n : int = index_offset ; n < index_count ; n++ )
							indices[n] = ram.readInt();
						
						index_offset = index_count;
					}
					else if ( opcode == MOLEHILL_DRAW )
					{
						if ( enabled ) draw();
					}
					else if ( opcode == MOLEHILL_BIND )
					{
						var id : int = ram.readInt();
						
						bindTexture( id );
					}
					else if ( opcode == MOLEHILL_SET_BLENDING + MOLEHILL_SRC_ONE + MOLEHILL_DST_ZERO )
					{
						setBlending( "ONE", "ZERO" );
					}
					else if ( opcode == MOLEHILL_SET_BLENDING + MOLEHILL_SRC_ONE + MOLEHILL_DST_ONE )
					{
						setBlending( "ONE", "ONE" );
					}
					else if ( opcode == MOLEHILL_SET_BLENDING + MOLEHILL_SRC_ALPHA + MOLEHILL_ONE_MINUS_SRC_ALPHA )
					{
						setBlending( "SRC_ALPHA", "ONE_MINUS_SRC_ALPHA" );
					}
					else if ( opcode == MOLEHILL_SET_BLENDING + MOLEHILL_SRC_ZERO + MOLEHILL_ONE_MINUS_SRC_COLOR )
					{
						setBlending( "ZERO", "ONE_MINUS_SRC_COLOR" );
					}
					else if ( opcode == MOLEHILL_SET_DEPTHTEST + MOLEHILL_IGNORE + MOLEHILL_ALWAYS )
					{
						setDepthTest( false, "ALWAYS" );
					}
					else if ( opcode == MOLEHILL_SET_DEPTHTEST + MOLEHILL_IGNORE + MOLEHILL_LESS_OR_EQUAL )
					{
						setDepthTest( false, "LESS_EQUAL" );
					}
					else if ( opcode == MOLEHILL_SET_DEPTHTEST + MOLEHILL_WRITE + MOLEHILL_ALWAYS )
					{
						setDepthTest( true, "ALWAYS" );
					}
					else if ( opcode == MOLEHILL_SET_DEPTHTEST + MOLEHILL_WRITE + MOLEHILL_LESS_OR_EQUAL )
					{
						setDepthTest( true, "LESS_EQUAL" );
					}
					else if ( opcode == MOLEHILL_SET_VIEWPORT )
					{
						var vx : int = ram.readInt();
						var vy : int = ram.readInt();
						var vw : int = ram.readInt();
						var vh : int = ram.readInt();

						setViewport( vx, vy, vw, vh );
					}
					else if ( opcode == MOLEHILL_SET_CULLING + MOLEHILL_NONE )
					{
						setCulling( "NONE" );
					}
					else if ( opcode == MOLEHILL_SET_CULLING + MOLEHILL_FRONT )
					{
						setCulling( "FRONT" );
					}
					else if ( opcode == MOLEHILL_SET_CULLING + MOLEHILL_BACK )
					{
						setCulling( "BACK" );
					}
					else
					{
						trace( "invalid masm opcode : " + opcode + " last_opcode : " + last_opcode );
					}
					
					last_opcode = opcode;
				}
			}
			
			trace( getTimeStamp() + " end execute( " + data_ptr + " ) " + count + " instructions, " + (ram.position - data_ptr) + " bytes read." );
		}
		public function draw() : void
		{
			//trace( getTimeStamp() + " draw()" );
			
			if ( index_count > 0 )
			{
				ib.upload( indices, 0, index_count );

				if ( use_texturing )
				{
					if ( textures[tid] == null ) trace( "invalid texture id=" + tid );
					
					setTexture( 1, textures[tid] );
					
					setProgram( sp0 );
					
					vb0.upload( vertices, 0, vertex_count );
					
					setVertexStream( 0, vb0, 0, "FLOAT_4" );
					setVertexStream( 1, vb0, 4, "FLOAT_4" );
					setVertexStream( 2, vb0, 8, "FLOAT_2" );
				}
				else
				{
					setProgram ( sp1 );
					
					vb1.upload( vertices, 0, vertex_count );
					
					setVertexStream( 0, vb1, 0, "FLOAT_4" );
					setVertexStream( 1, vb1, 4, "FLOAT_4" );
				}
				
				setProgramConstantsMatrixTransposed( "VERTEX", 0, matrix );
				
				drawTriangles( ib, 0, index_count / 3 );
			}
			
			vertex_count = 0;
			index_count = 0;

			vertex_offset = 0;
			index_offset = 0;
		}
		
		public function bindTexture( id : int ) : void
		{
			//trace( getTimeStamp() + " bindTexture( " + id + " )" );
			
			tid = id;
		}

		public function uploadTexture( channels : int, width : int, height : int, data_ptr : uint ) : void
		{
			//trace( getTimeStamp() + " uploadTexture( " + channels + ", " + width + ", " + height + ", " + data_ptr + " )" );
			
			var bitmapData : BitmapData = new BitmapData( width, height, true, 0x00 );
			var rect : Rectangle = new Rectangle( 0, 0, width, height );
			var last_position : uint = ram.position;
			var texture : Texture3D = createTexture( width, height, "RGBA", false );
			var abgr : uint, argb : uint, i : uint;
			var x : int, y : int;
			
			if ( channels == 4 )
			{
				ram.position = data_ptr;
				bitmapData.lock();
				for ( y = 0 ; y < height ; y++ )
				{
					for ( x = 0 ; x < width ; x++ )
					{
						abgr = ram.readUnsignedInt();
						argb = (abgr & 0xFF000000) | ((abgr & 0x00FF0000) >> 16) & 0x000000FF | (abgr & 0x0000FF00) | ((abgr & 0x000000FF) << 16) & 0x00FF0000;
						bitmapData.setPixel32( x, y, argb );
					}
				}
				bitmapData.unlock();
				ram.position = last_position;
				texture.upload( bitmapData );
			}
			else if ( channels == 1 )
			{
				ram.position = data_ptr;
				bitmapData.lock();
				for ( y = 0 ; y < height ; y++ )
				{
					for ( x = 0 ; x < width ; x++ )
					{
						i = ram.readUnsignedByte();
						argb = (i << 24) & 0xFF000000 | (i << 16) & 0x00FF0000 | (i << 8) & 0x0000FF00 | (i << 0) & 0x000000FF;
						bitmapData.setPixel32( x, y, argb );
					}
				}
				bitmapData.unlock();
				ram.position = last_position;
				texture.upload( bitmapData );
			}
			
			textures[tid] = texture;
		}
		
		public function setViewport( left : int, top : int, width : int, height : int ) : void
		{
			//trace( getTimeStamp() + " setViewport( " + left + ", " + top + ", " + width + ", " + height + " ) not implemented yet..." );
		}
	}

}
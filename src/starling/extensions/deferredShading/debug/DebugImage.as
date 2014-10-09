package starling.extensions.deferredShading.debug
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;
	import starling.utils.VertexData;
	
	/** This custom display objects renders a regular, n-sided polygon. */
	public class DebugImage extends DisplayObject
	{
		private static var PROGRAM_NAME:String = 'DebugImage';
		private static var PROGRAM_NAME_CHANNEL_R:String = 'DebugImageChannelR';
		private static var PROGRAM_NAME_CHANNEL_A:String = 'DebugImageChannelA';
		
		// vertex data 
		private var mVertexData:VertexData;
		private var mVertexBuffer:VertexBuffer3D;
		
		// index data
		private var mIndexData:Vector.<uint>;
		private var mIndexBuffer:IndexBuffer3D;
		
		// helper objects (to avoid temporary objects)
		private static var sHelperMatrix:Matrix = new Matrix();
		private static var sRenderAlpha:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 1.0];
		
		public var mTexture:Texture;
		
		private var mWidth:Number, mHeight:Number;
		
		/** Creates a regular polygon with the specified redius, number of edges, and color. */
		public function DebugImage(texture:Texture, width:Number, height:Number)
		{
			mTexture = texture;
			
			mWidth = width;
			mHeight = height;
			
			// setup vertex data and prepare shaders
			setupVertices();
			createBuffers();
			registerPrograms();
			
			// handle lost context
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
		
		/** Disposes all resources of the display object. */
		public override function dispose():void
		{
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			if (mVertexBuffer) mVertexBuffer.dispose();
			if (mIndexBuffer)  mIndexBuffer.dispose();
			
			super.dispose();
		}
		
		private function onContextCreated(event:Event):void
		{
			// the old context was lost, so we create new buffers and shaders.
			createBuffers();
			registerPrograms();
		}
		
		/** Returns a rectangle that completely encloses the object as it appears in another 
		 * coordinate system. */
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if (resultRect == null) resultRect = new Rectangle();
			
			var transformationMatrix:Matrix = targetSpace == this ? 
				null : getTransformationMatrix(targetSpace, sHelperMatrix);
			
			return mVertexData.getBounds(transformationMatrix, 0, -1, resultRect);
		}
		
		/** Creates the required vertex- and index data and uploads it to the GPU. */ 
		private function setupVertices():void
		{
			var i:int;
			
			// create vertices
			
			mVertexData = new VertexData(4);
			mVertexData.setUniformColor(0xFFF000);
			
			mVertexData.setTexCoords(0, 0.0, 0.0);
			mVertexData.setTexCoords(1, 1.0, 0.0);
			mVertexData.setTexCoords(2, 0.0, 1.0);
			mVertexData.setTexCoords(3, 1.0, 1.0);
			
			mVertexData.setPosition(0, 0.0, 0.0);
			mVertexData.setPosition(1, mWidth, 0.0);
			mVertexData.setPosition(2, 0.0, mHeight);
			mVertexData.setPosition(3, mWidth, mHeight);			
			
			// create indices that span up the triangles
			
			mIndexData = new <uint>[0,1,2,2,1,3];
		}
		
		/** Creates new vertex- and index-buffers and uploads our vertex- and index-data to those
		 *  buffers. */ 
		private function createBuffers():void
		{
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			if (mVertexBuffer) mVertexBuffer.dispose();
			if (mIndexBuffer)  mIndexBuffer.dispose();
			
			mVertexBuffer = context.createVertexBuffer(mVertexData.numVertices, VertexData.ELEMENTS_PER_VERTEX);
			mVertexBuffer.uploadFromVector(mVertexData.rawData, 0, mVertexData.numVertices);
			
			mIndexBuffer = context.createIndexBuffer(mIndexData.length);
			mIndexBuffer.uploadFromVector(mIndexData, 0, mIndexData.length);
		}
		
		/** Renders the object with the help of a 'support' object and with the accumulated alpha
		 * of its parent object. */
		public override function render(support:RenderSupport, alpha:Number):void
		{
			if(!mTexture)
			{
				return;
			}
			
			// always call this method when you write custom rendering code!
			// it causes all previously batched quads/images to render.
			support.finishQuadBatch();
			
			// make this call to keep the statistics display in sync.
			support.raiseDrawCount();
			
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			// apply the current blendmode
			support.applyBlendMode(false);
			
			// activate program (shader) and set the required buffers / constants 
			
			var programName:String;
			
			if(_showChannel == 0)
			{
				programName = PROGRAM_NAME_CHANNEL_R;
			}
			else if(_showChannel == 3)
			{
				programName = PROGRAM_NAME_CHANNEL_A;
			}
			else
			{
				programName = PROGRAM_NAME;
			}
			
			context.setProgram(Starling.current.getProgram(programName));
			context.setVertexBufferAt(0, mVertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_2); 
			context.setVertexBufferAt(1, mVertexBuffer, VertexData.TEXCOORD_OFFSET, Context3DVertexBufferFormat.FLOAT_2);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, support.mvpMatrix3D, true);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, sRenderAlpha, 1)
			context.setTextureAt(0, mTexture.base);
				
			// finally: draw the object!
			context.drawTriangles(mIndexBuffer, 0, 2);
			
			// reset buffers
			context.setTextureAt(0, null);
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
		}
		
		/** Creates vertex and fragment programs from assembly. */
		private static function registerPrograms():void
		{
			var target:Starling = Starling.current;
			if (target.hasProgram(PROGRAM_NAME)) return; // already registered
			
			var vertexProgramCode:String =
				ShaderUtils.joinProgramArray(
					[
						'm44 op, va0, vc0', // 4x4 matrix transform to output space
						'mov v0, va1'
					]
				);
			
			var fragmentProgramCode:String =
				ShaderUtils.joinProgramArray(
					[
						'tex ft0, v0, fs0 <2d, clamp, linear, mipnone>',
						'mov ft0.w, fc0.w',
						'mov oc, ft0'
					]
				);
			
			var fragmentProgramCodeChannelR:String =
				ShaderUtils.joinProgramArray(
					[
						'tex ft0, v0, fs0 <2d, clamp, linear, mipnone>',
						'mov ft0.yz, ft0.xx',
						'mov ft0.w, fc0.w',
						'mov oc, ft0'
					]
				);
			
			var fragmentProgramCodeChannelA:String =
				ShaderUtils.joinProgramArray(
					[
						'tex ft0, v0, fs0 <2d, clamp, linear, mipnone>',
						'mov ft0.xyz, ft0.www',
						'mov ft0.w, fc0.w',
						'mov oc, ft0'
					]
				);
			
			var vertexProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			var fragmentProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode);		
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode);			
			target.registerProgram(PROGRAM_NAME, vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
			
			// R
			
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCodeChannelR);			
			target.registerProgram(PROGRAM_NAME_CHANNEL_R, vertexProgramAssembler.agalcode,	fragmentProgramAssembler.agalcode);
			
			// A
			
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCodeChannelA);			
			target.registerProgram(PROGRAM_NAME_CHANNEL_A, vertexProgramAssembler.agalcode,	fragmentProgramAssembler.agalcode);
		}
		
		private var _showChannel:int = -1;
		
		// Valid values: -1, 0, 3
		public function get showChannel():int
		{ 
			return _showChannel;
		}
		public function set showChannel(value:int):void
		{
			_showChannel = value;
		}		
	}
}
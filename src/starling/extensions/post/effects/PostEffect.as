package starling.extensions.post.effects
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	
	import starling.core.Starling;
	import starling.extensions.deferredShading.RenderPass;
	import starling.extensions.utils.ShaderUtils;
	import starling.extensions.post.PostEffectRenderer;
	import starling.textures.Texture;

	public class PostEffect
	{
		private static const RESAMPLE:String = 'PostEffectResample';
		private static const SUPERSAMPLE:String = 'PostEffectSupersample';
		private static const SUPERSAMPLE_X:String = 'PostEffectSupersampleX';
		
		// Apply types
		
		public static const ADD:String = 'Add';
		public static const OVERWRITE:String = 'Overwrite';
		
		// Compiled programs
		
		private static var resampleProgram:Program3D;
		private static var supersampleProgram:Program3D;
		private static var supersampleProgramX:Program3D;
	
		// Misc
		
		public var renderer:PostEffectRenderer;
		public var numDrawCalls:int = 0;
		
		public var input:Texture;
		public var output:Texture;
		
		private var c0:Vector.<Number> = new <Number>[0,0,0,0];
		private var c1:Vector.<Number> = new <Number>[0,0,0,0];	
		private var c2:Vector.<Number> = new <Number>[0,0,0,0];	
		private var dirty:Boolean = true;		

		/**
		 * Effect blend mode.
		 */
		//public var blendMode:String = EffectBlendMode.ALPHA;

		public function render():void
		{		
			if(dirty) prepare();
			
			/*switch(blendMode)
			{
				case EffectBlendMode.NONE:
					overlay.blendFactorSource = Context3DBlendFactor.ONE;
					overlay.blendFactorDestination = Context3DBlendFactor.ZERO;
					break;
				case EffectBlendMode.ADD:
					overlay.blendFactorSource = Context3DBlendFactor.ONE;
					overlay.blendFactorDestination = Context3DBlendFactor.ONE;
					break;
				case EffectBlendMode.ALPHA:
					overlay.blendFactorSource = Context3DBlendFactor.SOURCE_ALPHA;
					overlay.blendFactorDestination = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
					break;
				case EffectBlendMode.MULTIPLY:
					overlay.blendFactorSource = Context3DBlendFactor.DESTINATION_COLOR;
					overlay.blendFactorDestination = Context3DBlendFactor.ZERO;
					break;
			}*/
		}
		
		public function invalidate():void
		{
			prepare();
		}
		
		public function dispose(programs:Boolean = false):void
		{
			if(programs) Starling.current.deleteProgram(RESAMPLE);
		}
		
		protected function prepare():void
		{			
			dirty = false;
			
			if(!Starling.current.getProgram(RESAMPLE))
			{
				resampleProgram =  ShaderUtils.registerProgram(RESAMPLE, VERTEX_SHADER, FRAGMENT_SHADER, 2);
			}
			
			if(!Starling.current.getProgram(SUPERSAMPLE))
			{
				supersampleProgram =  ShaderUtils.registerProgram(SUPERSAMPLE, UBER_RESAMPLE_VERTEX_SHADER, UBER_RESAMPLE_FRAGMENT_SHADER, 2);
			}
			
			if(!Starling.current.getProgram(SUPERSAMPLE_X))
			{
				supersampleProgramX =  ShaderUtils.registerProgram(SUPERSAMPLE_X, UBER_RESAMPLE_X_VERTEX_SHADER, UBER_RESAMPLE_X_FRAGMENT_SHADER, 2);
			}
		}
		
		/*--------------------
		Resample
		--------------------*/
		
		/**
		 * Downscales image by using linear filtering. Best results are achieved when source is 2x larger than target. 
		 * Use more expensive supersample() for better quality downsampled image.
		 */
		protected function resample(source:Texture, target:Texture):void
		{
			var context:Context3D = Starling.current.context;
			
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			context.setTextureAt(0, source.base);
			context.setProgram(resampleProgram);
			context.setRenderToTexture(target.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();
			
			context.drawTriangles(renderer.overlayIndexBuffer);
			
			context.setRenderToBackBuffer();
		}
		
		/**
		 * Downscales image by using supersampling. Best result achieved when source is exactly 2x larger than target.
		 */
		protected function supersample(source:Texture, target:Texture):void
		{
			var context:Context3D = Starling.current.context;
			
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			context.setTextureAt(0, source.base);
			context.setProgram(supersampleProgram);
			
			c0[0] = 1 / target.nativeWidth;
			c0[1] = 1 / target.nativeHeight;			
			c1[0] = 0.5 / target.nativeWidth;
			c1[1] = 0.5 / target.nativeHeight;
			c1[2] = 9;
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, c0);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, c1);
			context.setRenderToTexture(target.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();
			
			context.drawTriangles(renderer.overlayIndexBuffer);
			
			context.setRenderToBackBuffer();
		}
		
		/**
		 * Downscales image by using supersampling. Best result achieved when source is exactly 2x larger than target. X axis only.
		 */
		protected function supersampleX(source:Texture, target:Texture):void
		{
			var context:Context3D = Starling.current.context;
			
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			context.setTextureAt(0, source.base);
			context.setProgram(supersampleProgramX);
			
			c0[0] = 1 / target.nativeWidth;
			c0[1] = 1 / target.nativeHeight;			
			c1[0] = 0.5 / target.nativeWidth;
			c1[1] = 0.5 / target.nativeHeight;
			c1[2] = 3;
			c2[0] = 1 / target.nativeWidth;
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, c0);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, c1);
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 2, c2);
			context.setRenderToTexture(target.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();
			
			context.drawTriangles(renderer.overlayIndexBuffer);
			
			context.setRenderToBackBuffer();
		}
		
		/*---------------------------
		Properties
		---------------------------*/
		
		public var enabled:Boolean = true;
		
		protected var _applyType:String = PostEffect.ADD; 
		
		/**
		 * This defines how the effect will be applied, possible values being:
		 * <ul>
		 * <li>PostEffect.ADD - Effect output will be rendered over regular scene with ADD blend mode.</li>
		 * <li>PostEffect.OVERWRITE - Effect will modify the scene and its output should overwrite current render.</li>
		 * </ul>
		 * 
		 * Note: currently only ADD mode works.
		 */
		public function get applyType():String 
		{
			return _applyType;
		}
		
		/*---------------------------
		Downsample
		---------------------------*/		
		
		private const VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Move UV coords to varying-0
					"mov v0, va1",
					// Set vertex position as output
					"mov op, va0"			
				]
			);
		
		/**
		 * Combines previously rendered maps.
		 */
		private const FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[					
					// Sample source texture	
					"tex ft0, v0, fs0 <2d,clamp,linear>",
					"mov oc, ft0",
				]
			);
		
		/*---------------------------
		Supersample
		---------------------------*/
		
		private const UBER_RESAMPLE_VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Move UV coords to varying-0
					"mov v0, va1",
					// Set vertex position as output
					"mov op, va0"		
				]
			);
		private const UBER_RESAMPLE_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[		
					// Adjust to pixel center (not needed???)
					//'add ft0.xy, v0.xy, fc1.xy',
					'mov ft0.xy, v0.xy',
					'mov ft1.xy, ft0.xy',
					
					// Sample 9 times, add results, divide by 9
					// center
					'tex ft2, ft1.xy, fs0 <2d,clamp,linear>',
					
					// up
					'sub ft1.xy, ft0.xy, fc0.wy',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// down
					'add ft1.xy, ft0.xy, fc0.wy',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// right
					'add ft1.xy, ft0.xy, fc0.xw',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// left
					'sub ft1.xy, ft0.xy, fc0.xw',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// nw
					'sub ft1.xy, ft0.xy, fc0.xy',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// sw
					'sub ft1.x, ft0.x, fc0.x',
					'add ft1.y, ft0.y, fc0.y',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// ne
					'add ft1.x, ft0.x, fc0.x',
					'sub ft1.y, ft0.y, fc0.y',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// se
					'add ft1.xy, ft0.xy, fc0.xy',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					'div ft2, ft2, fc1.z',
					
					'mov oc, ft2'
				]
			);
		
		/*---------------------------
		Supersample X
		---------------------------*/
		
		private const UBER_RESAMPLE_X_VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Move UV coords to varying-0
					'mov v0, va1',
					
					'mov vt0, va0',
					'sub vt0.xy, vt0.xy, vc2.xy',					
					
					// Set vertex position as output
					'mov op, vt0'	
				]
			);
		private const UBER_RESAMPLE_X_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[		
					// Adjust to pixel center (not needed???)
					//'add ft0.xy, v0.xy, fc1.xy',
					'mov ft0.xy, v0.xy',
					'mov ft1.xy, ft0.xy',
					
					// Sample 3 times, add results, divide by 3 (horizontally only)
					// center
					'tex ft2, ft1.xy, fs0 <2d,clamp,linear>',
					
					// right
					'add ft1.xy, ft0.xy, fc0.xw',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					// left
					'sub ft1.xy, ft0.xy, fc0.xw',
					'tex ft3, ft1.xy, fs0 <2d,clamp,linear>',
					'add ft2, ft2, ft3',
					
					'div ft2, ft2, fc1.z',
					
					'mov oc, ft2'
				]
			);
	}
}
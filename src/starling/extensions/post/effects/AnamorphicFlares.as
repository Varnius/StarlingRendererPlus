package starling.extensions.post.effects
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	
	import starling.core.Starling;
	import starling.extensions.deferredShading.RenderPass;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;
	
	public class AnamorphicFlares extends BlurBase
	{
		public static const ANAMORPHIC_FLARES:String = 'PostEffectAnamorphicFlares';
		public static const THRESHOLD:String = 'PostEffectAnamorphicFlaresThreshold';
		
		// Cache	
		
		private var thresholdProgram:Program3D;
		private var anamorphicFlaresProgram:Program3D;
		
		public var a2:Texture;		
		public var a4:Texture;
		public var b4:Texture;
		public var a8:Texture;
		public var a16:Texture;
		public var a32:Texture;	
		public var a64:Texture;	
		public var b64:Texture;	
		
		private var fc0Params:Vector.<Number> = new <Number>[0, 0, 0, 0];
		private var fc1LuminosityValues:Vector.<Number> = new <Number>[0.2126, 0.7152, 0.0722, 0];
		/**
		 * Color threshold.
		 */
		public var threshold:Number = 0.4;
		
		/**
		 * Blend amount.
		 */
		public var intensity:Number = 1.0;
		
		public function AnamorphicFlares()
		{
			_applyType = PostEffect.ADD;
			numDrawCalls = 11;
		}
		
		override public function render():void
		{
			super.render();
			
			var context:Context3D = Starling.current.context;
			var sw:int = Starling.current.nativeStage.stageWidth;
			var sh:int = Starling.current.nativeStage.stageHeight;
			
			// Downscale
			
			supersampleX(input, a2);		
			supersampleX(a2, a4);
			
			// Render scene with color threshold		
			
			// Set attributes
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);				
			
			fc0Params[0] = threshold;
			fc0Params[3] = 1 - threshold;
			
			// Set constants
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, fc0Params, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, fc1LuminosityValues, 1);
			
			// Set samplers
			context.setTextureAt(0, a4.base);
			
			// Set program
			context.setProgram(thresholdProgram);
			
			// Render
			context.setRenderToTexture(b4.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();
			
			context.drawTriangles(renderer.overlayIndexBuffer);			
			context.setRenderToBackBuffer(); 
			
			// Downsample again
			
			supersampleX(b4, a8);
			supersampleX(a8, a16);
			supersampleX(a16, a32);
			supersampleX(a32, a64);	
			
			// Blur
			
			blurWide(a64, b64, true, false);
			blurWide(b64, a64, true, false);
			blurWide(a64, b64, true, false);
			
			// Render final
			
			fc0Params[0] = intensity;
			
			// Set attributes
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			
			// Set samplers
			context.setTextureAt(0, b64.base);
			
			// Set program
			context.setProgram(anamorphicFlaresProgram);		
			
			// Set constants
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, fc0Params, 1);
			
			// Combine
			context.setRenderToTexture(a64.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();			
			context.drawTriangles(renderer.overlayIndexBuffer);				
			context.setRenderToBackBuffer();
			
			// Clean up
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
			context.setTextureAt(0, null);
			context.setTextureAt(1, null);
			
			output = a64;
		}
		
		override public function dispose(programs:Boolean = false):void
		{
			super.dispose(programs);
			
			if(programs)
			{
				Starling.current.deleteProgram(ANAMORPHIC_FLARES);
				Starling.current.deleteProgram(THRESHOLD);
			}			
			
			if(a2) a2.dispose();
			if(a4) a4.dispose();
			if(b4) b4.dispose();
			if(a8) a8.dispose();
			if(a16) a16.dispose();
			if(a32) a32.dispose();
			if(a64) a64.dispose();
			if(b64) b64.dispose();
		}
		
		override protected function prepare():void
		{		
			super.prepare();
			
			var context:Context3D = Starling.current.context;
			
			if(!Starling.current.getProgram(THRESHOLD))
			{
				thresholdProgram = ShaderUtils.registerProgram(THRESHOLD, THRESHOLD_VERTEX_SHADER, THRESHOLD_FRAGMENT_SHADER, 2);
			}
			
			if(!Starling.current.getProgram(ANAMORPHIC_FLARES))
			{
				 anamorphicFlaresProgram = ShaderUtils.registerProgram(ANAMORPHIC_FLARES, FLARES_VERTEX_SHADER, FLARES_FRAGMENT_SHADER, 1);
			}
			
			var sw:int = Starling.current.nativeStage.stageWidth;
			var sh:int = Starling.current.nativeStage.stageHeight;
			
			dispose();
			
			a2 = Texture.empty(sw / 2, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			a4 = Texture.empty(sw / 4, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			b4 = Texture.empty(sw / 4, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			a8 = Texture.empty(sw / 8, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			a16 = Texture.empty(sw / 16, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			a32 = Texture.empty(sw / 32, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			a64 = Texture.empty(sw / 64, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			b64 = Texture.empty(sw / 64, sh / 1, false, false, true, -1, Context3DTextureFormat.BGRA);
		}
		
		/*---------------------------
		Bloom program
		---------------------------*/		
		
		protected const FLARES_VERTEX_SHADER:String = 			
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
		protected const FLARES_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[							
					// Sample flares
					"tex ft1, v0, fs0 <2d,clamp,linear>",
					
					'mul ft1, ft1, fc0.x',
					//'add ft0, ft0, ft1',
					'mov oc, ft1',
				]
			);
		
		/*---------------------------
		Threshold program
		---------------------------*/
		
		protected const THRESHOLD_VERTEX_SHADER:String = 			
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
		protected const THRESHOLD_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[						
					'tex ft0, v0, fs0 <2d,clamp,linear>',
					'mul ft2.xyz, ft0.xyz, fc1.xyz',
					'add ft1.x, ft2.x, ft2.y',
					'add ft1.x, ft1.x, ft2.z',
					
					'ifl ft1.x, fc0.x',					
						'mov ft0.xyz, fc1.www',					
					'eif',
					
					'mov oc, ft0'
				]
			);	
		
		/**
		 * Combines previously rendered maps.
		 */
		/*protected const THRESHOLD_FRAGMENT_SHADER:String =
			Utils.joinProgramArray(
				[					
					// Formula: saturate((Color – Threshold) / (1 – Threshold))
					"tex ft0, v0, fs0 <2d,clamp,linear>",
					"sub ft0.xyz, ft0.xyz, fc0.xxx",
					"div ft0.xyz, ft0.xyz, fc0.www",
					"sat ft0, ft0",		
					
					// Return final color
					"mov oc, ft0",
				]
			);*/
	}
}
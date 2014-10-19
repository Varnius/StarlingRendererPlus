package starling.extensions.post
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.extensions.post.effects.PostEffect;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;

	public class PostEffectRenderer extends Sprite
	{
		private static const POST_EFFECT_RENDERER_PROGRAM:String = 'PostEffectRendererProgram';		
		
		// Quad
		
		public var overlayVertexBuffer:VertexBuffer3D;
		public var overlayIndexBuffer:IndexBuffer3D;
		protected var vertices:Vector.<Number> = new <Number>[-1, 1, 0, 0, 0, -1, -1, 0, 0, 1, 1,  1, 0, 1, 0, 1, -1, 0, 1, 1];
		protected var indices:Vector.<uint> = new <uint>[0,1,2,2,1,3];
		
		// RTs
		
		public var scene:Texture;
			
		private var mostRecentRender:Texture;
		private var renderTarget:Texture;
		
		// Misc		
		
		private var prepared:Boolean = false;
		private var outputs:Vector.<Texture> = new Vector.<Texture>();
		
		public function PostEffectRenderer(antiAliasing:int = 0)
		{
			_antiAliasing = antiAliasing;
			prepare();	
			
			// Handle lost context			
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
		
		override public function render(support:RenderSupport, parentAlpha:Number):void
		{
			var noEnabledEffects:Boolean = true;
			
			// Render directly to current RT if there are no enabled effects
			
			for each(var e:PostEffect in _effects)
			{
				if(e.enabled)
				{
					noEnabledEffects = false;
					break;
				}
			}
			
			if(!noEnabledEffects)
			{
				var context:Context3D = Starling.context;
				var prevRenderTarget:Texture = support.renderTarget;
				
				// Render scene
				
				support.setRenderTarget(scene, _antiAliasing);
				support.clear();
			}			
			
			super.render(support, parentAlpha);	
			
			if(noEnabledEffects)
			{
				return;
			}
			
			support.setRenderTarget(prevRenderTarget);
			
			var output:Texture;
			outputs.length = 0;
			
			for each(e in _effects)
			{
				if(e.enabled && e.applyType == PostEffect.ADD) 
				{
					e.input = output ? output : scene;					
					e.render();
					output = e.output;
					outputs.push(output);
					support.raiseDrawCount(e.numDrawCalls);
				}			
			}

			outputs.unshift(scene);
			
			// Render final comination of scene and effect outputs
			// Default functionality is additively blend everything
			
			if(_customRenderer)
			{
				_customRenderer(this, context, outputs, support);
			}
			else
			{			
				for each(var o:Texture in outputs)
				{
					context.setVertexBufferAt(0, overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
					context.setVertexBufferAt(1, overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);                      
					context.setTextureAt(0, o.base);
					
					context.setProgram(Starling.current.getProgram(POST_EFFECT_RENDERER_PROGRAM));			
					
					if(outputs.indexOf(o) == 0) 
						context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA); 
					else
						context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE); 
					
					context.drawTriangles(overlayIndexBuffer);
					support.raiseDrawCount();
				}
				
				context.setVertexBufferAt(0, null);
				context.setVertexBufferAt(1, null);
				context.setTextureAt(0, null);
				
			}			
		}
		
		private function prepare():void
		{
			var context:Context3D = Starling.current.context;
			var target:Starling = Starling.current;
			var w:Number = Starling.current.nativeStage.stageWidth;
			var h:Number = Starling.current.nativeStage.stageHeight;			
			
			// Create a quad for rendering full screen passes
			
			overlayVertexBuffer = context.createVertexBuffer(4, 5);
			overlayVertexBuffer.uploadFromVector(vertices, 0, 4);
			overlayIndexBuffer = context.createIndexBuffer(6);
			overlayIndexBuffer.uploadFromVector(indices, 0, 6);
			
			// Create RTs
			
			scene = Texture.empty(w, h, false, false, true, -1, Context3DTextureFormat.BGRA);
			
			// Invalidate each effect
			
			for each(var e:PostEffect in _effects)
			{
				e.invalidate();
			}
			
			// Create programs
			
			if(target.hasProgram(POST_EFFECT_RENDERER_PROGRAM))
			{
				return;	
			}
			
			var vertexProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, VERTEX_SHADER, 2);			
			var fragmentProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, FRAGMENT_SHADER, 2);			
			Starling.current.registerProgram(POST_EFFECT_RENDERER_PROGRAM, vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
			
			prepared = true;
		}
		
		override public function dispose():void
		{
			super.dispose();
			
			scene.dispose();
			overlayIndexBuffer.dispose();
			overlayVertexBuffer.dispose();
			
			for each(var e:PostEffect in _effects)
			{
				e.dispose(true);
			}
		}
		
		public function getEffectByClass(clazz:Class):PostEffect
		{
			for each(var e:PostEffect in _effects)
			{
				if(e is clazz) return e;					
			}
			
			return null;
		}
		
		/*-----------------------------
		Event handlers
		-----------------------------*/
		
		private function onContextCreated(event:Event):void
		{
			prepared = false;
			prepare();
		}
		
		/*---------------------------
		Programs
		---------------------------*/		
		
		protected const VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[
					'mov op, va0',
					'mov v0, va1'
				]
			);
		
		/**
		 * Combines previously rendered maps.
		 */
		protected const FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[
					// Sample inputRT
					'tex oc, v0, fs0 <2d, clamp, linear, mipnone>',
				]
			);
		
		/*--------------------------
		Properties	
		--------------------------*/
		
		private var _effects:Vector.<PostEffect> = new <PostEffect>[];
		
		/**
		 * A list of effects to use.
		 */
		public function get effects():Vector.<PostEffect>
		{ 
			return _effects; 
		}
		public function set effects(value:Vector.<PostEffect>):void
		{
			_effects = value;
			
			for each(var e:PostEffect in value)
			{
				e.renderer = this;
			}
		}
		
		private var _customRenderer:Function;
		
		/**
		 * This function should combine the scene and effect outputs. Overrides default functionality of PostEffectRenderer if set.
		 * The benefit could be performance gained by composing all outputs and scene in single pass (while renderer does this by rendering
		 * everything separately with additive blending.
		 * <br />
		 * Should have the signature of <code>function(r:PostEffectRenderer, c:Context3D, o:Vector.<Texture>):void</code>
		 */
		public function get customRenderer():Function
		{ 
			return _customRenderer; 
		}
		public function set customRenderer(value:Function):void
		{
			_customRenderer = value;
		}
		
		private var _antiAliasing:int;
		
		public function get antiAliasing():int
		{ 
			return _antiAliasing; 
		}
		public function set antiAliasing(value:int):void
		{
			_antiAliasing = value;
		}
	}
}
package starling.extensions.deferredShading.lights
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	
	import starling.core.RenderSupport;
	import starling.display.DisplayObject;
	import starling.extensions.deferredShading.renderer_internal;
	import starling.textures.Texture;
	
	use namespace renderer_internal;
	
	/**
	 * Base for all types of lights.
	 * Use one of the subclasses.
	 */
	public class Light extends DisplayObject
	{		
		public function Light(color:uint, strength:Number = 1.0)
		{
			this.color = color;
			this.strength = strength;
		}
		
		public function renderShadowMap(
			support:RenderSupport,
			occluders:Texture,
			vertexBuffer:VertexBuffer3D,
			indexBuffer:IndexBuffer3D
		):void
		{
			throw new Error('This method should be overriden in a subclass.');
		}
		
		/*-----------------------------
		Properties
		-----------------------------*/
		
		protected var assembler:AGALMiniAssembler = new AGALMiniAssembler();
		
		protected var _color:uint;
		renderer_internal var _colorR:Number;
		renderer_internal var _colorG:Number;
		renderer_internal var _colorB:Number;
		
		public function get color():uint
		{ 
			return _color;
		}
		public function set color(value:uint):void
		{
			_colorR = ((value >> 16) & 0xff) / 255.0;
			_colorG = ((value >>  8) & 0xff) / 255.0;
			_colorB = ( value        & 0xff) / 255.0;
			_color = value;
		}
		
		protected var _strength:Number;
		
		public function get strength():Number
		{ 
			return _strength;
		}
		public function set strength(value:Number):void
		{
			_strength = value;
		}
		
		protected var _castsShadows:Boolean = false;
		
		/**
		 * This light will cast shadows if set to true.
		 */
		public function get castsShadows():Boolean
		{ 
			return _castsShadows;
		}
		public function set castsShadows(value:Boolean):void
		{
			_castsShadows = value;
		}		
	}
}
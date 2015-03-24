package starling.extensions.deferredShading.lights
{
	import starling.display.DisplayObject;
	import starling.extensions.deferredShading.renderer_internal;
	
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
		
		/*-----------------------------
		Properties
		-----------------------------*/
		
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
	}
}
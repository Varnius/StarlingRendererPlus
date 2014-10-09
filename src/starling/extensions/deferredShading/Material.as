package starling.extensions.deferredShading
{
	import starling.textures.Texture;
	
	public class Material extends Texture
	{
		public static const DEFAULT_SPECULAR_POWER:Number = 10.0;
		public static const DEFAULT_SPECULAR_INTENSITY:Number = 3.0;
		
		public var diffuse:Texture;
		public var normal:Texture;
		public var depth:Texture;
		//public var specular:Texture;
		public var specularIntensity:Number = DEFAULT_SPECULAR_INTENSITY;
		public var specularPower:Number = DEFAULT_SPECULAR_POWER;
		
		public function Material(diffuse:Texture, normal:Texture = null, depth:Texture = null/*, specular:Texture = null*/)
		{
			this.diffuse = diffuse;
			this.normal = normal;
			this.depth = depth;
			//this.specular = specular;
		}
		
		override public function get width():Number
		{
			return diffuse.width;
		}
		
		override public function get height():Number
		{
			return diffuse.height;
		}
	}
}
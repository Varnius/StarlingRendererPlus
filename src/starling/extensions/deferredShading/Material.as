package starling.extensions.deferredShading
{
	import starling.textures.Texture;
	import starling.utils.VertexData;
	import flash.geom.Rectangle;
	
	public class Material extends Texture
	{
		public static const DEFAULT_SPECULAR_POWER:Number = 20.0;
		public static const DEFAULT_SPECULAR_INTENSITY:Number = 1.0;
		
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
		
		/*-----------------------
		Overrides
		-----------------------*/
		
		override public function get width():Number
		{
			return diffuse.width;
		}
		
		override public function get height():Number
		{
			return diffuse.height;
		}
		
		/** @inheritDoc */
		override public function adjustVertexData(vertexData:VertexData, vertexID:int, count:int):void
		{
			diffuse.adjustVertexData(vertexData, vertexID, count);
		}
		
		/** @inheritDoc */
		override public function adjustTexCoords(texCoords:Vector.<Number>,
												 startIndex:int=0, stride:int=0, count:int=-1):void
		{
			diffuse.adjustTexCoords(texCoords, startIndex, stride, count);
		}
		
		/** @inheritDoc */
		override public function get frame():Rectangle { return diffuse.frame; }
	}
}
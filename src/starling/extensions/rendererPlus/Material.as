// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus
{
    import flash.display3D.textures.TextureBase;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import starling.rendering.VertexData;
    import starling.textures.ConcreteTexture;
    import starling.textures.Texture;

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

        override public function setupVertexPositions(vertexData:VertexData, vertexID:int = 0,
                                                      attrName:String = "position",
                                                      bounds:Rectangle = null):void
        {
            diffuse.setupVertexPositions(vertexData, vertexID, attrName, bounds);
        }

        override public function setupTextureCoordinates(vertexData:VertexData, vertexID:int = 0,
                                                         attrName:String = "texCoords"):void
        {
            diffuse.setupTextureCoordinates(vertexData, vertexID, attrName);
        }

        override public function localToGlobal(u:Number, v:Number, out:Point = null):Point
        {
            return diffuse.localToGlobal(u, v, out);
        }

        override public function globalToLocal(u:Number, v:Number, out:Point = null):Point
        {
            return diffuse.globalToLocal(u, v, out);
        }

        override public function setTexCoords(vertexData:VertexData, vertexID:int, attrName:String,
                                              u:Number, v:Number):void
        {
            diffuse.setTexCoords(vertexData, vertexID, attrName, u, v);
        }

        override public function getTexCoords(vertexData:VertexData, vertexID:int,
                                              attrName:String = "texCoords", out:Point = null):Point
        {
            return diffuse.getTexCoords(vertexData, vertexID, attrName, out);
        }

        override public function get frame():Rectangle
        {
            return diffuse.frame;
        }

        override public function get frameWidth():Number
        {
            return diffuse.frame ? diffuse.frame.width : diffuse.width;
        }

        override public function get frameHeight():Number
        {
            return diffuse.frame ? diffuse.frame.height : diffuse.height;
        }

        override public function get width():Number
        {
            return diffuse.width;
        }

        override public function get height():Number
        {
            return diffuse.height;
        }

        override public function get nativeWidth():Number
        {
            return diffuse.nativeWidth;
        }

        override public function get nativeHeight():Number
        {
            return diffuse.nativeHeight;
        }

        override public function get scale():Number
        {
            return diffuse.scale;
        }

        override public function get base():TextureBase
        {
            return diffuse.base;
        }

        override public function get root():ConcreteTexture
        {
            return diffuse.root;
        }

        override public function get format():String
        {
            return diffuse.format;
        }

        override public function get mipMapping():Boolean
        {
            return diffuse.mipMapping;
        }

        override public function get premultipliedAlpha():Boolean
        {
            return diffuse.premultipliedAlpha;
        }

        override public function get transformationMatrix():Matrix
        {
            return diffuse.transformationMatrix;
        }

        override public function get transformationMatrixToRoot():Matrix
        {
            return diffuse.transformationMatrixToRoot;
        }
    }
}
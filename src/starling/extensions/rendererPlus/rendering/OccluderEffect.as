// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.rendering
{
    import flash.display3D.Context3D;
    import flash.display3D.Context3DProgramType;

    import starling.extensions.utils.ShaderUtils;
    import starling.rendering.MeshEffect;
    import starling.rendering.Program;
    import starling.rendering.VertexDataFormat;
    import starling.textures.Texture;
    import starling.utils.RenderUtil;

    public class OccluderEffect extends MeshEffect
    {
        public static const VERTEX_FORMAT:VertexDataFormat = VertexDataFormat.fromString("position:float2, texCoords:float2");

        // Shader constants

        private var constants:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 1.0];

        override protected function createProgram():Program
        {
            var vertexShader:String, fragmentShader:String;

            if(texture)
            {
                vertexShader = ShaderUtils.joinProgramArray(
                        [
                            "m44 op, va0, vc0",
                            "mov v0, va1",
                        ]
                );

                fragmentShader = ShaderUtils.joinProgramArray(
                        [
                            RenderUtil.createAGALTexOperation("ft0", "v0", 0, texture),
                            "mul oc, ft0, fc0",
                        ]
                );
            }
            else
            {
                vertexShader = ShaderUtils.joinProgramArray(
                        [
                            "m44 op, va0, vc0",
                        ]
                );

                fragmentShader = ShaderUtils.joinProgramArray(
                        [
                            "mov oc, fc0",
                        ]
                );
            }

            return Program.fromSource(vertexShader, fragmentShader);
        }

        override protected function get programVariantName():uint
        {
            return texture ? 0 : 1;
        }

        override protected function beforeDraw(context:Context3D):void
        {
            var tex:Texture = texture;

            program.activate(context);
            vertexFormat.setVertexBufferAt(0, vertexBuffer, "position");
            context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, mvpMatrix3D, true);

            if(tex)
            {
                var repeat:Boolean = textureRepeat && tex.root.isPotTexture;
                RenderUtil.setSamplerStateAt(0, tex.mipMapping, textureSmoothing, repeat);
                context.setTextureAt(0, tex.base);
                vertexFormat.setVertexBufferAt(1, vertexBuffer, "texCoords");
            }

            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, constants, 1);
        }

        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }
    }
}

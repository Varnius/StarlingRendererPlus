// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.rendering
{
    import flash.display3D.Context3D;
    import flash.display3D.Context3DProgramType;

    import starling.extensions.rendererPlus.Material;
    import starling.extensions.rendererPlus.RenderPass;
    import starling.extensions.rendererPlus.display.RendererPlus;
    import starling.extensions.utils.ShaderUtils;
    import starling.rendering.MeshEffect;
    import starling.rendering.Program;
    import starling.rendering.VertexDataFormat;
    import starling.utils.RenderUtil;

    public class PlusMeshEffect extends MeshEffect
    {
        public static const VERTEX_FORMAT:VertexDataFormat = VertexDataFormat.fromString("position:float2, texCoords:float2, color:bytes4");

        // Shader constants

        private var deferredQuadNormal:Vector.<Number> = new <Number>[0.5, 0.5, 1.0, 1.0];
        private var deferredQuadSpecularParams:Vector.<Number> = new <Number>[Material.DEFAULT_SPECULAR_POWER, Material.DEFAULT_SPECULAR_INTENSITY, 1.0, 0.0];
        private var specularParams:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private var constants:Vector.<Number> = new <Number>[1.0, 0.0, 0.0, 0.0];
        private var constants2:Vector.<Number> = new <Number>[0.01, 0.0, 0.0, 0.0];

        override protected function createProgram():Program
        {
            var vertexShader:String, fragmentShader:String;
            var pass:String = RendererPlus.renderPass;

            if(texture)
            {
                if(pass == RenderPass.MRT)
                {
                    vertexShader = ShaderUtils.joinProgramArray(
                            [
                                "m44 op, va0, vc0",     // 4x4 matrix transform to output clip-space
                                "mov v0, va1",          // pass texture coordinates to fragment program
                                "mul v1, va2, vc4"      // multiply alpha (vc4) with color (va2), pass to fp
                            ]
                    );

                    fragmentShader = ShaderUtils.joinProgramArray(
                            [
                                RenderUtil.createAGALTexOperation("ft0", "v0", 0, texture),

                                // Sample normal
                                RenderUtil.createAGALTexOperation("ft4", "v0", 1, texture),
                                //'tex ft4, v1, fs1 <sampler_flags>',

                                // Sample depth
                                RenderUtil.createAGALTexOperation("ft3", "v0", 2, texture),
                                //'tex ft3, v1, fs2 <sampler_flags>',

                                // Set depth yz to specular power/intensity
                                'mov ft3.y, fc5.x',
                                'mov ft3.z, fc5.y',

                                // Mask normal/depth maps by diffuse map alpha (multiply by 0 if alpha is less than threshold specified by fc7.x)
                                // This is useful when user just passes rectangular single-color
                                // normal map and wants to use it for the area covered by diffuse color,
                                'sge ft7.x, ft0.w, fc7.x',
                                'mul ft4, ft4, ft7.x',
                                'mov oc1, ft4',
                                'mul ft3, ft3, ft0.w',

                                // Multiply diffuse by 1 minus depth value
                                'sub ft5.x, fc6.x, ft3.x',
                                'mul ft0.xyz, ft0.xyz, ft5.x',

                                'mov oc2, ft3',

                                "mul oc, ft0, v1",   // multiply color with texel color,
                            ]
                    );
                }
                else return super.createProgram();
            }
            else
            {
                if(pass == RenderPass.MRT)
                {
                    vertexShader = ShaderUtils.joinProgramArray(
                            [
                                "m44 op, va0, vc0", // 4x4 matrix transform to output clipspace
                                "mul v0, va2, vc4"  // multiply alpha (vc0) with color (va1)
                            ]
                    );

                    // fc5, deferred quad normal [0.5, 0.5, 1.0, 0]
                    // fc6, deferred quad specular/depth params [specPower, specIntensity, defaultDepth, 0.0]

                    fragmentShader = ShaderUtils.joinProgramArray(
                            [
                                // Diffuse render target
                                'mov oc, v0',

                                // Normal render target
                                'mov oc1, fc5',

                                // Depth render target
                                // Write specular params to depth yz
                                'mov oc2.xyzw, fc6.zxyz'
                            ]
                    );
                }
                else return super.createProgram();
            }

            return Program.fromSource(vertexShader, fragmentShader, 2);
        }

        override protected function get programVariantName():uint
        {
            // Only 2 options here - either regular pass or a MRT one
            var mrtBit:uint = RendererPlus.renderPass == RenderPass.MRT ? 1 : 0;
            var baseBits:uint = super.programVariantName;
            return baseBits |= mrtBit << 4;
        }

        override protected function beforeDraw(context:Context3D):void
        {
            super.beforeDraw(context);

            if(RendererPlus.renderPass == RenderPass.MRT)
            {
                if(texture)
                {
                    var material:Material = texture as Material;
                    var normalMapPresent:Boolean;
                    var depthMapPresent:Boolean;

                    if(material)
                    {
                        normalMapPresent = material.normal;
                        depthMapPresent = material.depth;
                        specularParams[0] = material.specularPower;
                        specularParams[1] = material.specularIntensity;
                    }
                    else
                    {
                        normalMapPresent = false;
                        depthMapPresent = false;
                        specularParams[0] = 0;
                        specularParams[1] = 0;
                    }

                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 5, specularParams, 1);
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 6, constants, 1);
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 7, constants2, 1);
                    context.setTextureAt(1, normalMapPresent ? material.normal.base : RendererPlus.defaultNormalMap.base);
                    context.setTextureAt(2, depthMapPresent ? material.depth.base : RendererPlus.defaultDepthMap.base);
                }
                else
                {
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 5, deferredQuadNormal, 1);
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 6, deferredQuadSpecularParams, 1);
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 7, constants, 1);
                }
            }
        }

        override protected function afterDraw(context:Context3D):void
        {
            if(texture)
            {
                if(RendererPlus.renderPass == RenderPass.MRT)
                {
                    // Unset textures
                    context.setTextureAt(1, null);
                    context.setTextureAt(2, null);
                }
            }

            super.afterDraw(context);
        }

        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }
    }
}

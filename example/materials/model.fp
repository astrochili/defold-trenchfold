//
// model.fp
// github.com/astrochili/defold-trenchfold
// Copyright (c) 2022 Roman Silin
// MIT license. See LICENSE for details.
//

varying highp vec4 var_position;
varying mediump vec3 var_normal;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;

void main() {
    vec4 color = texture2D(tex0, var_texcoord0.xy);

    if (color.a == 0.0) {
       discard;
    }

    float ambient_part = 0.8;

    vec3 diffuse = vec3(1.0 - ambient_part);
    diffuse = vec3(ambient_part) + diffuse * vec3(var_normal.y);

    gl_FragColor = vec4(color.rgb * diffuse.rgb, 1.0);
}
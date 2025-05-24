#version 330 core

// Based on: http://wdobbie.com/post/gpu-text-rendering-with-vector-textures/

struct Glyph {
    int start, count;
};

struct Curve {
    vec2 p0, p1, p2;
};

uniform isamplerBuffer glyphs;
uniform samplerBuffer curves;
uniform vec4 color;

// Controls for debugging and exploring:
uniform float antiAliasingWindowSize = 1.0;
uniform bool enableSuperSamplingAntiAliasing = true;
uniform bool enableControlPointsVisualization = false;
uniform bool enableQuadBorderVisualization = false;

// Multi-sampling control
uniform int multiSampleMode = 0; // 0=Analytical, 1=4x multi-sample

in vec2 uv;
flat in int bufferIndex;

out vec4 result;

Glyph loadGlyph(int index) {
    Glyph result;
    ivec2 data = texelFetch(glyphs, index).xy;
    result.start = data.x;
    result.count = data.y;
    return result;
}

Curve loadCurve(int index) {
    Curve result;
    result.p0 = texelFetch(curves, 3*index+0).xy;
    result.p1 = texelFetch(curves, 3*index+1).xy;
    result.p2 = texelFetch(curves, 3*index+2).xy;
    return result;
}

float computeCoverage(float inverseDiameter, vec2 p0, vec2 p1, vec2 p2) {
    if (p0.y > 0 && p1.y > 0 && p2.y > 0) return 0.0;
    if (p0.y < 0 && p1.y < 0 && p2.y < 0) return 0.0;

    // Note: Simplified from abc formula by extracting a factor of (-2) from b.
    vec2 a = p0 - 2*p1 + p2;
    vec2 b = p0 - p1;
    vec2 c = p0;

    float t0, t1;
    if (abs(a.y) >= 1e-5) {
        // Quadratic segment, solve abc formula to find roots.
        float radicand = b.y*b.y - a.y*c.y;
        if (radicand <= 0) return 0.0;
    
        float s = sqrt(radicand);
        t0 = (b.y - s) / a.y;
        t1 = (b.y + s) / a.y;
    } else {
        // Linear segment, avoid division by a.y, which is near zero.
        float t = p0.y / (p0.y - p2.y);
        if (p0.y < p2.y) {
            t0 = -1.0;
            t1 = t;
        } else {
            t0 = t;
            t1 = -1.0;
        }
    }

    float alpha = 0;
    
    if (t0 >= 0 && t0 < 1) {
        float x = (a.x*t0 - 2.0*b.x)*t0 + c.x;
        alpha += clamp(x * inverseDiameter + 0.5, 0, 1);
    }

    if (t1 >= 0 && t1 < 1) {
        float x = (a.x*t1 - 2.0*b.x)*t1 + c.x;
        alpha -= clamp(x * inverseDiameter + 0.5, 0, 1);
    }

    return alpha;
}

// Binary coverage for multi-sampling (no anti-aliasing window)
float computeBinaryCoverage(vec2 p0, vec2 p1, vec2 p2) {
    if (p0.y > 0 && p1.y > 0 && p2.y > 0) return 0.0;
    if (p0.y < 0 && p1.y < 0 && p2.y < 0) return 0.0;

    vec2 a = p0 - 2*p1 + p2;
    vec2 b = p0 - p1;
    vec2 c = p0;

    float t0, t1;
    if (abs(a.y) >= 1e-5) {
        float radicand = b.y*b.y - a.y*c.y;
        if (radicand <= 0) return 0.0;
        
        float s = sqrt(radicand);
        t0 = (b.y - s) / a.y;
        t1 = (b.y + s) / a.y;
    } else {
        float t = p0.y / (p0.y - p2.y);
        if (p0.y < p2.y) {
            t0 = -1.0;
            t1 = t;
        } else {
            t0 = t;
            t1 = -1.0;
        }
    }

    float winding = 0.0;
    
    if (t0 >= 0 && t0 < 1) {
        float x = (a.x*t0 - 2.0*b.x)*t0 + c.x;
        if (x >= 0) winding += 1.0;  // Binary: either inside or outside
    }

    if (t1 >= 0 && t1 < 1) {
        float x = (a.x*t1 - 2.0*b.x)*t1 + c.x;
        if (x >= 0) winding -= 1.0;  // Binary: either inside or outside
    }

    return winding;
}

vec2 rotate(vec2 v) {
    return vec2(v.y, -v.x);
}

void main() {
    float alpha = 0;

    if (multiSampleMode == 0) {
        // ORIGINAL: Single sample with analytical anti-aliasing
        vec2 inverseDiameter = 1.0 / (antiAliasingWindowSize * fwidth(uv));

        Glyph glyph = loadGlyph(bufferIndex);
        for (int i = 0; i < glyph.count; i++) {
            Curve curve = loadCurve(glyph.start + i);

            vec2 p0 = curve.p0 - uv;
            vec2 p1 = curve.p1 - uv;
            vec2 p2 = curve.p2 - uv;

            alpha += computeCoverage(inverseDiameter.x, p0, p1, p2);
            if (enableSuperSamplingAntiAliasing) {
                alpha += computeCoverage(inverseDiameter.y, rotate(p0), rotate(p1), rotate(p2));
            }
        }

        if (enableSuperSamplingAntiAliasing) {
            alpha *= 0.5;
        }
        
    } else {
       vec2 f_uv = abs(vec2(dFdx(uv.x), dFdy(uv.y)));
        
        // Better 8-sample pattern
        vec2 samples[8] = vec2[8](
            (vec2(0.5/8.0, 0.5/8.0) - 0.5) * f_uv,
            (vec2(1.5/8.0, 4.5/8.0) - 0.5) * f_uv,
            (vec2(2.5/8.0, 8.5/8.0) - 0.5) * f_uv,
            (vec2(3.5/8.0, 3.5/8.0) - 0.5) * f_uv,
            (vec2(4.5/8.0, 6.5/8.0) - 0.5) * f_uv,
            (vec2(5.5/8.0, 1.5/8.0) - 0.5) * f_uv,
            (vec2(6.5/8.0, 7.5/8.0) - 0.5) * f_uv,
            (vec2(7.5/8.0, 2.5/8.0) - 0.5) * f_uv
        );
        
        float coverages[8] = float[8](0,0,0,0,0,0,0,0);
        
        Glyph glyph = loadGlyph(bufferIndex);
        for (int i = 0; i < glyph.count; i++) {
            Curve curve = loadCurve(glyph.start + i);
            vec2 p0 = curve.p0 - uv;
            vec2 p1 = curve.p1 - uv;
            vec2 p2 = curve.p2 - uv;
            
            for (int c = 0; c < 8; c++) {
                vec2 offset = samples[c];
                coverages[c] += computeBinaryCoverage(p0 - offset, p1 - offset, p2 - offset);
            }
        }
        
        // Resolve: count non-zero samples
        float resolved = 0.0;
        for (int c = 0; c < 8; c++) {
            resolved += (coverages[c] != 0.0) ? 1.0 : 0.0;
        }
        alpha = resolved / 8.0;
    }

    alpha = clamp(alpha, 0.0, 1.0);
    result = color * alpha;

    // Quad border visualization for debugging padding issues
    if (enableQuadBorderVisualization) {
        vec2 fw = fwidth(uv);
        float border_width = 1.0 * max(fw.x, fw.y); // 3 pixel border for visibility
        
        // Distance to each edge of the UV quad
        float dist_left = uv.x;
        float dist_right = 1.0 - uv.x;
        float dist_bottom = uv.y;
        float dist_top = 1.0 - uv.y;
        
        // Find minimum distance to any edge
        float dist_to_edge = min(min(dist_left, dist_right), min(dist_bottom, dist_top));
        
        // Only show border pixels (near edge but not filled)
        if (dist_to_edge < border_width) {
            // Mix red with existing color instead of replacing
            result = vec4(1.0, 0.0, 0.0, 1.0); // Pure red border for debugging
            return; // Early return to make border clearly visible
        }
        
        // Debug: Also show UV coordinates as colors to see the mapping
        // result = vec4(uv.x, uv.y, 0.0, 1.0); // R=X, G=Y coordinate
    }

    // Control points visualization for debugging
    if (enableControlPointsVisualization) {
        vec2 fw = fwidth(uv);
        float r = 4.0 * 0.5 * (fw.x + fw.y);
        
        Glyph glyph = loadGlyph(bufferIndex);
        for (int i = 0; i < glyph.count; i++) {
            Curve curve = loadCurve(glyph.start + i);

            vec2 p0 = curve.p0 - uv;
            vec2 p1 = curve.p1 - uv;
            vec2 p2 = curve.p2 - uv;

            if (dot(p0, p0) < r*r || dot(p2, p2) < r*r) {
                result = vec4(0, 1, 0, 1);  // Green for on-curve points
                return;
            }

            if (dot(p1, p1) < r*r) {
                result = vec4(1, 0, 1, 1);  // Magenta for control points
                return;
            }
        }
    }
}
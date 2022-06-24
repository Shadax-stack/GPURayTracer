#ifndef MATERIAL_GLSL
#define MATERIAL_GLSL

layout(std430) readonly buffer samplers {
    vec4 materialInstance[];
};

// https://casual-effects.com/research/McGuire2013CubeMap/paper.pdf
vec3 BlinnPhongNormalized(in vec3 albedo, in float shiny, in vec3 specular, in vec3 n, in vec3 v, in vec3 l) {
    vec3 h = normalize(v + l);
    float distribution = pow(max(dot(n, h), 0.0f), shiny);
    float reflectance = distribution * (shiny + 8.0f) / 8.0f;
    return (albedo + specular * reflectance) / M_PI;
}

vec3 BlinnPhongNormalizedPBR(in vec3 albedo, in float roughness, in float metallic, in vec3 n, in vec3 v, in vec3 l) {
    // GGX != beckman but this is the only remapping I know
    float shiny = 2 / (roughness * roughness) - 2;
    vec3 f0 = mix(vec3(0.04f), albedo, metallic);
    return BlinnPhongNormalized(albedo * (1.0f - metallic), shiny, f0, n, v, l);
}

vec3 ReflectiveTest(in vec3 albedo, in float roughness, in float metallic, in vec3 n, in vec3 v, in vec3 l) {
    vec3 r = reflect(-l, n);
    float dist = pow(max(dot(r, v), 0.0f), 256.0f);
    return 1000000000.0 * albedo * dist;
}

//#define LOGL_PBR
#ifdef LOGL_PBR

float DistributionTrowbridgeReitz(vec3 N, vec3 H, float roughness)
{
    float a = roughness *roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI * denom * denom;

    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 FresnelShlick(vec3 F0, float cosTheta)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 FresnelShlick(vec3 F0, vec3 n, vec3 d)
{
    return FresnelShlick(F0, max(dot(n, d), 0.0f));
}

#else

float DistributionTrowbridgeReitz(in vec3 n, in vec3 h, in float roughness) {
    float noh = max(dot(n, h), 0.0f);
    float a = roughness * roughness;
    float a2 = a * a;
    float k = (noh * noh * (a2 - 1.0f) + 1.0f);
    float div = M_PI * k * k;
    return a2 / div;
}

float GeometryShlickGGX(vec3 n, vec3 v, float k) {
    float nov = max(dot(n, v), 0.0f);
    return nov / (nov * (1.0 - k) + k);
}

float GeometrySmith(in vec3 n, in vec3 v, in vec3 l, in float roughness) {
    float k = roughness + 1;
    k = k * k / 8;
    return GeometryShlickGGX(n, v, k) * GeometryShlickGGX(n, l, k);
}

vec3 FresnelShlick(in vec3 f0, in vec3 n, in vec3 v) {
    return f0 + (1.0 - f0) * pow(clamp(1.0 - max(dot(n, v), 0.0f), 0.0, 1.0), 5.0);
}

#endif

// https://docs.google.com/document/d/1ZLT1-fIek2JkErN9ZPByeac02nWipMbO89oCW2jxzXo/edit
vec3 SingleScatterCookTorrace(in vec3 albedo, in float roughness, in float metallic, in vec3 n, in vec3 v, in vec3 l) {
    // Cook torrance
    vec3 f0 = mix(vec3(0.04f), albedo, metallic);
    vec3 h = normalize(v + l);
    vec3 specular = DistributionTrowbridgeReitz(n, h, roughness) * GeometrySmith(n, v, l, roughness)* FresnelShlick(f0, h, v) / max(4 * max(dot(n, v), 0.0f) * max(dot(n, l), 0.0f), 0.001f);
    // Energy conserving diffuse
    vec3 diffuse = (1.0 - FresnelShlick(f0, n, l)) * (1.0f - FresnelShlick(f0, n, v)) * albedo / M_PI;
    return specular + diffuse;
}
 


#define BRDF(a, r, m, n, v, l) SingleScatterCookTorrace(a, r, m, n, v, l)

#endif
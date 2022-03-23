// based on windows terminal original shader
Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
  float  Time;
  float  Scale;
  float2 Resolution;
  float4 Background;
};

// Scanline parameters
#define SCANLINE_FACTOR 0.3
#define SCALED_SCANLINE_PERIOD Scale
#define SCALED_GAUSSIAN_SIGMA (2.0*Scale)

// Noise parameters
#define NOISE_AMOUNT 0.3

// Chromatic Aberration parameters
#define CHROMATIC_SPREAD 1.3

static const float M_PI = 3.14159265f;


// Noise functions
// Source: https://gist.github.com/h3r/3a92295517b2bee8a82c1de1456431dc
float rand1(float n)  
{ 
    return frac(sin(n) * 43758.5453123); 
}

float rand2dTo1d(float2 value, float2 dotDir = float2(12.9898, 78.233))
{
	float2 smallValue = sin(value + Time);
	float random = dot(smallValue, dotDir);
	random = frac(sin(random) * 143758.5453);
	return random;
}

float Gaussian2D(float x, float y, float sigma)
{
    return 1/(sigma*sqrt(2*M_PI)) * exp(-0.5*(x*x + y*y)/sigma/sigma);
}

float4 Blur(Texture2D input, float2 tex_coord, float sigma)
{
    uint width, height;
    shaderTexture.GetDimensions(width, height);

    float texelWidth = 1.0f/width;
    float texelHeight = 1.0f/height;

    float4 color = { 0, 0, 0, 0 };

    int sampleCount = 5;

    for (int x = 0; x < sampleCount; x++)
    {
        float2 samplePos = { 0, 0 };

        samplePos.x = tex_coord.x + (x - sampleCount/2) * texelWidth;
        for (int y = 0; y < sampleCount; y++)
        {
            samplePos.y = tex_coord.y + (y - sampleCount/2) * texelHeight;
            if (samplePos.x <= 0 || samplePos.y <= 0 || samplePos.x >= width || samplePos.y >= height) continue;

            color += input.Sample(samplerState, samplePos) * Gaussian2D((x - sampleCount/2), (y - sampleCount/2), sigma);
        }
    }

    return color;
}

float4 Aberration(Texture2D input, float2 tex_coord)
{
    uint width, height;
    shaderTexture.GetDimensions(width, height);

    float texelWidth = 1.0f/width;
    float texelHeight = 1.0f/height;

    float2 samplePosR = { tex_coord.x + (CHROMATIC_SPREAD * texelWidth), tex_coord.y };
    float2 samplePosB = { tex_coord.x - (CHROMATIC_SPREAD * texelWidth), tex_coord.y };

    float4 rColor = input.Sample(samplerState, samplePosR);
    float4 gColor = input.Sample(samplerState, tex_coord);
    float4 bColor = input.Sample(samplerState, samplePosB);

    return float4(rColor.r, gColor.g, bColor.b, gColor.a);
}

float SquareWave(float y)
{
    return 1 - (floor(y / SCALED_SCANLINE_PERIOD) % 2) * SCANLINE_FACTOR;
}

float4 Scanline(float4 color, float4 pos)
{
    float wave = SquareWave(pos.y);

    if (length(color.rgb) < 0.2 && false)
    {
        return color + wave*0.1;
    }
    else
    {
        return color * wave;
    }
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    Texture2D input = shaderTexture;

    float4 color = Aberration(input, tex);
    color += Blur(input, tex, SCALED_GAUSSIAN_SIGMA) * 0.38;
    color = Scanline(color, pos);

    return color * (1 - NOISE_AMOUNT + rand2dTo1d(tex) * NOISE_AMOUNT);
}
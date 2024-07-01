using Amazon.Lambda.Core;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.Json.JsonSerializer))]

namespace HelloWorld
{
    public class Function
    {
        public string Handler(object input, ILambdaContext context)
        {
            return "Hello!";
        }
    }
}

using System.Collections.Generic;
using System.IO;

namespace Semmle.Extraction.CIL.Entities
{
    interface ILocal : IExtractedEntity
    {
    }

    class LocalVariable : LabelledEntity, ILocal
    {
        readonly MethodImplementation method;
        readonly int index;
        readonly Type type;

        public LocalVariable(Context cx, MethodImplementation m, int i, Type t) : base(cx)
        {
            method = m;
            index = i;
            type = t;
        }

        public override void WriteId(TextWriter trapFile)
        {
            trapFile.WriteSubId(method);
            trapFile.Write('_');
            trapFile.Write(index);
        }

        public override string IdSuffix => ";cil-local";

        public override IEnumerable<IExtractionProduct> Contents
        {
            get
            {
                yield return type;
                yield return Tuples.cil_local_variable(this, method, index, type);
            }
        }
    }
}

import haxe.macro.Expr;
import haxe.macro.Expr.MetadataEntry;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Type.BaseType;
import haxe.macro.Type.ModuleType;

class AS3MetadataGenerator {
    public static function generate():Void {
        Context.onGenerate((types:Array<Type>) -> {
            for (type in types) {
                switch (type) {
                    case TInst(t, params):
                        var classType = t.get();
                        generateAS3MetadataForBaseType(t.get());
                        for (field in classType.fields.get()) {
                            generateAS3MetadataForClassField(field);
                        }
                    default:
                }
            }
        });
    }

    private static final INSPECTABLE_FIELD_NAMES:Array<String> = [
        "defaultValue",
        "format",
        "minValue",
        "maxValue",
        "verbose",
    ];

    private static function generateAS3MetadataForBaseType(type:BaseType):Void {
        for (bindableMeta in type.meta.extract("bindable")) {
            generateAS3BindableMetadata(bindableMeta, type.meta);
        }
        for (bindableMeta in type.meta.extract(":bindable")) {
            generateAS3BindableMetadata(bindableMeta, type.meta);
        }
        for (defaultPropMeta in type.meta.extract("defaultXmlProperty")) {
            generateAS3DefaultPropertyMetadata(defaultPropMeta, type.meta);
        }
        for (defaultPropMeta in type.meta.extract(":defaultXmlProperty")) {
            generateAS3DefaultPropertyMetadata(defaultPropMeta, type.meta);
        }
        for (eventMeta in type.meta.extract("event")) {
            generateAS3EventMetadata(eventMeta, type.meta);
        }
        for (eventMeta in type.meta.extract(":event")) {
            generateAS3EventMetadata(eventMeta, type.meta);
        }
    }

    private static function generateAS3MetadataForClassField(field:ClassField):Void {
        for (bindableMeta in field.meta.extract("bindable")) {
            generateAS3BindableMetadata(bindableMeta, field.meta);
        }
        for (bindableMeta in field.meta.extract(":bindable")) {
            generateAS3BindableMetadata(bindableMeta, field.meta);
        }
        for (inspectMeta in field.meta.extract("inspectable")) {
            generateAS3InspectableMetadata(inspectMeta, field.meta);
        }
        for (inspectMeta in field.meta.extract(":inspectable")) {
            generateAS3InspectableMetadata(inspectMeta, field.meta);
        }
    }

    private static function generateAS3BindableMetadata(bindableMeta:MetadataEntry, metaAccess:MetaAccess):Void {
        if (bindableMeta.params.length == 0) {
            var param = macro Bindable;
            metaAccess.add(":meta", [param], bindableMeta.pos);
            return;
        }
        if (bindableMeta.params.length != 1) {
            return;
        }
        switch (bindableMeta.params[0].expr) {
            case EBinop(OpAssign, e1, e2):
                var fieldName:String = null;
                var fieldValue:String = null;
                switch (e1.expr) {
                    case EConst(CIdent(s)):
                        fieldName = s;
                    default:
                }
                switch (e2.expr) {
                    case EConst(CString(s)):
                        fieldValue = s;
                    default:
                }
                if (fieldName == "event" && fieldValue != null) {
                    var param = macro Bindable($i{fieldName}=$v{fieldValue});
                    metaAccess.add(":meta", [param], bindableMeta.pos);
                }
            case EConst(CString(s, kind)):
                var param = macro Bindable($v{s});
                metaAccess.add(":meta", [param], bindableMeta.pos);
            default:
        }
    }

    private static function generateAS3DefaultPropertyMetadata(defaultPropMeta:MetadataEntry, metaAccess:MetaAccess):Void {
        if (defaultPropMeta.params.length != 1) {
            return;
        }
        switch (defaultPropMeta.params[0].expr) {
            case EConst(CString(s, kind)):
                var param = macro DefaultProperty($v{s});
                metaAccess.add(":meta", [param], defaultPropMeta.pos);
            default:
        }
    }

    private static function generateAS3EventMetadata(eventMeta:MetadataEntry, metaAccess:MetaAccess):Void {
        if (eventMeta.params.length != 1) {
            return;
        }
        var qnameParts:Array<String> = [];
        switch (eventMeta.params[0].expr) {
            case EField(e, fieldName):
                var current = e;
                while (current != null) {
                    switch (current.expr) {
                        case EField(next, qnamePart):
                            qnameParts.unshift(qnamePart);
                            current = next;
                        case EConst(CIdent(s)):
                            qnameParts.unshift(s);
                            current = null;
                        default:
                            current = null;
                    }
                }
                var eventQname = qnameParts.join(".");
                var qnameType = Context.getType(eventQname);
                switch (qnameType) {
                    case TInst(t, params):
                        var eventClassType = t.get();
                        var eventName = getFieldStringValue(fieldName, eventClassType.statics.get());
                        if (eventName != null) {
                            var param = macro Event(name=$v{eventName},type=$v{eventQname});
                            metaAccess.add(":meta", [param], eventMeta.pos);
                            return;
                        }
                    default:
                }
            default:
        }
    }

    private static function generateAS3InspectableMetadata(inspectMeta:MetadataEntry, metaAccess:MetaAccess):Void {
        var paramExprs:Array<Expr> = [];
        for (param in inspectMeta.params) {
            switch (param.expr) {
                case EBinop(OpAssign, e1, e2):
                    var fieldName:String = null;
                    var fieldValue:String = null;
                    switch (e1.expr) {
                        case EConst(CIdent(s)):
                            fieldName = s;
                        default:
                    }
                    switch (e2.expr) {
                        case EConst(CString(s)):
                            fieldValue = s;
                        default:
                    }
                    if (INSPECTABLE_FIELD_NAMES.indexOf(fieldName) != -1 && fieldValue != null) {
                        paramExprs.push(macro $i{fieldName}=$v{fieldValue});
                    }
                default:
            }
        }
        var param = macro Inspectable($a{paramExprs});
        metaAccess.add(":meta", [param], inspectMeta.pos);
    }

    private static function getFieldStringValue(fieldName:String, fields:Array<ClassField>):String {
        for (field in fields) {
            if (field.name == fieldName) {
                switch (field.expr().expr) {
                    case TCast(e, m):
                        switch (e.expr) {
                            case TConst(TString(s)):
                                return s;
                            default:
                        }
                    case TConst(TString(s)):
                        return s;
                    default:
                }
                break;
            }
        }
        return null;
    }
}
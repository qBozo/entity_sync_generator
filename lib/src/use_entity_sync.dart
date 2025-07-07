part of 'builders.dart';

Builder useEntitySyncBuilder(BuilderOptions options) {
  return SharedPartBuilder(
      [UseEntitySyncGenerator()], 'use_entity_sync_builder');
}

class UseEntitySyncGenerator extends GeneratorForAnnotation<UseEntitySync> {
  late Iterable<ParameterElement> requiredPositionalArguments;
  late Iterable<ParameterElement> namedArguments;
  late Element baseElement;
  late Element element;
  late Map<String, DartType> fields;
  late Iterable<DartObject> serializableFields;
  DartObject? keyField;
  DartObject? remoteKeyField;
  DartObject? flagField;
  late StringBuffer sourceBuilder;

  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    sourceBuilder = StringBuffer();
    final visitor = ModelVisitor();
    this.element = element;

    baseElement = annotation.read('baseClass').typeValue.element!;
    baseElement.visitChildren(visitor);

    requiredPositionalArguments =
        visitor.parameters.where((element) => element.isRequiredPositional);
    namedArguments = visitor.parameters.where((element) => element.isNamed);
    fields = visitor.fields;

    serializableFields = annotation.read('fields').listValue.where((obj) {
      final type = obj.type;
      final element = type?.element;
      return type != null && element != null && element is ClassElement;
    });

    if (!annotation.read('keyField').isNull) {
      keyField = annotation.read('keyField').objectValue;
    }
    if (!annotation.read('remoteKeyField').isNull) {
      remoteKeyField = annotation.read('remoteKeyField').objectValue;
    }
    if (!annotation.read('flagField').isNull) {
      flagField = annotation.read('flagField').objectValue;
    }

    sourceBuilder.writeln(
        '// ignore_for_file: non_constant_identifier_names');
    generateProxyClass();
    generateSerializerClass();
    generateFactoryClass();
    generateEntitySyncClass();

    return sourceBuilder.toString();
  }

  void generateProxyClass() {
    final baseClassName = baseElement.displayName;
    final proxyClassName = '${baseClassName}Proxy';
    sourceBuilder.writeln(
        'class $proxyClassName extends $baseClassName with ProxyMixin<$baseClassName>, SyncableMixin, SerializableMixin{');

    sourceBuilder.write("$proxyClassName(");

    for (final parameter in requiredPositionalArguments) {
      sourceBuilder.write("$parameter,");
    }

    if (namedArguments.isNotEmpty) {
      sourceBuilder.write("{");

      namedArguments.forEach((element) {
        sourceBuilder.write("${element.type} ${element.name}, ");
      });

      sourceBuilder.write("}");
    }

    sourceBuilder.write(") : super(");

    for (final parameter in requiredPositionalArguments) {
      sourceBuilder.write("${parameter.name},");
    }

    namedArguments.forEach((element) {
      sourceBuilder.write("${element.name}: ${element.name},");
    });

    sourceBuilder.writeln(");");

    sourceBuilder.writeln("@override");
    sourceBuilder.writeln("Map<String, dynamic> toMap() { return {");

    namedArguments.forEach((element) {
      sourceBuilder.write("'${element.name}': ${element.name},");
    });

    sourceBuilder.writeln("};}");

    sourceBuilder.writeln("@override");
    sourceBuilder
        .writeln("$proxyClassName copyFromMap(Map<String, dynamic> data) {");

    sourceBuilder.writeln("return $proxyClassName(");

    namedArguments.forEach((element) {
      sourceBuilder.write("${element.name}: data['${element.name}'],");
    });
    sourceBuilder.writeln(");");
    sourceBuilder.writeln("}");

    sourceBuilder.write("final keyField = ");
    if (keyField == null) {
      sourceBuilder.writeln('null');
    } else {
      generateSerializableField(keyField!);
    }
    sourceBuilder.writeln(';');

    sourceBuilder.write("final remoteKeyField = ");
    if (remoteKeyField == null) {
      sourceBuilder.writeln('null');
    } else {
      generateSerializableField(remoteKeyField!);
    }
    sourceBuilder.writeln(';');

    sourceBuilder.write("final flagField = ");
    if (flagField == null) {
      sourceBuilder.writeln('null');
    } else {
      generateSerializableField(flagField!);
    }
    sourceBuilder.writeln(';');

    sourceBuilder
        .writeln("$proxyClassName.fromEntity($baseClassName instance): super(");

    for (final parameter in requiredPositionalArguments) {
      sourceBuilder.write("instance.${parameter.name},");
    }

    namedArguments.forEach((element) {
      sourceBuilder.write("${element.name}: instance.${element.name},");
    });

    sourceBuilder.writeln(");");

    sourceBuilder.writeln('}');
  }

  void generateSerializerClass() {
    final baseClassName = baseElement.displayName;
    final proxyClassName = '${baseClassName}Proxy';
    final serializerClassName = 'Base${baseClassName}Serializer';

    sourceBuilder.writeln(
        "class $serializerClassName extends Serializer<$proxyClassName> {");

    sourceBuilder.writeln("""
    $serializerClassName({Map<String, dynamic> data, $proxyClassName instance, String prefix = ''}): 
                          super(data: data, instance: instance, prefix: prefix);
    """);

    sourceBuilder.writeln("@override");
    sourceBuilder.write("final fields = [");
    serializableFields.forEach((element) {
      generateSerializableField(element);
      sourceBuilder.write(',');
    });
    sourceBuilder.writeln("];");

    final methods = <String>[];
    serializableFields.forEach((element) {
      final reader = ConstantReader(element);
      String name = reader.read('name').stringValue;
      name = "${name[0].toUpperCase()}${name.substring(1)}";

      String returnType = "dynamic";
      final typeElement = element.type?.element;
      if (typeElement is ClassElement) {
        switch (typeElement.displayName) {
          case "StringField":
            returnType = "String";
            break;
          case "IntegerField":
            returnType = "int";
            break;
          case "DateTimeField":
          case "DateField":
            returnType = "DateTime";
            break;
          case "BoolField":
            returnType = "bool";
            break;
          case "DoubleField":
            returnType = "double";
            break;
        }
      }

      final methodName = "validate$name";
      methods.add(methodName);

      sourceBuilder.writeln("""$returnType $methodName($returnType value) {
      return value;
    }""");
    });

    sourceBuilder.writeln("@override");
    sourceBuilder.write("Map toMap() {");
    sourceBuilder.write("return {");
    methods.forEach((element) {
      sourceBuilder.write("'$element': $element,");
    });
    sourceBuilder.write("};");
    sourceBuilder.write("}");

    sourceBuilder.writeln("@override");
    sourceBuilder
        .writeln("$proxyClassName createInstance(Map<String, dynamic> data) {");

    sourceBuilder.writeln("return $proxyClassName(");

    serializableFields.forEach((element) {
      String name = ConstantReader(element).read('name').stringValue;
      final constantReaderSource = ConstantReader(element).read('source');

      final source =
          constantReaderSource.isNull ? name : constantReaderSource.stringValue;

      sourceBuilder.writeln("$source: data['$name'],");
    });
    sourceBuilder.writeln("shouldSync: false,");
    sourceBuilder.writeln(");");

    sourceBuilder.writeln("}");
    sourceBuilder.writeln('}');
  }

  void generateFactoryClass() {
    final baseClassName = baseElement.displayName;
    final proxyClassName = '${baseClassName}Proxy';
    final factoryClassName = '${proxyClassName}Factory';

    sourceBuilder.writeln(
        'class $factoryClassName extends ProxyFactory<$proxyClassName, $baseClassName> {');
    sourceBuilder.writeln('@override');
    sourceBuilder
        .writeln('$proxyClassName fromInstance($baseClassName instance) {');
    sourceBuilder.writeln('return $proxyClassName.fromEntity(instance);');
    sourceBuilder.writeln('}');
    sourceBuilder.writeln('}');
  }

  void generateEntitySyncClass() {
    sourceBuilder.writeln('class \$_${element.displayName} {}');
  }

  void generateSerializableField(DartObject element) {
    final reader = ConstantReader(element);

    final name = reader.read('name').stringValue;
    final prefix = reader.read('prefix').isNull ? '' : reader.read('prefix').stringValue;
    final source = reader.read('source').isNull ? name : reader.read('source').stringValue;
    final type = element.type?.element?.displayName ?? 'UnknownField';

    final prefixArg = prefix.isEmpty ? '' : ",prefix: '$prefix'";
    sourceBuilder.write("$type('$name'$prefixArg, source: '$source')");
  }
}

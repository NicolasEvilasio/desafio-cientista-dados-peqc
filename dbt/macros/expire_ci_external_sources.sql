{% macro expire_ci_external_sources() %}
    {% if target.name == 'ci' and execute %}
        {% for node in graph.sources.values() if node.external %}
            {% set relation = source(node.source_name, node.name) %}
            {% set sql %}
                create or replace external table {{ relation }}
                options (
                    format = '{{ node.external.options.format }}',
                    uris = ['{{ node.external.location }}'],
                    expiration_timestamp = timestamp_add(current_timestamp(), interval 48 hour)
                )
            {% endset %}
            {% do log('expiration ' ~ relation, info = true) %}
            {% do run_query(sql) %}
        {% endfor %}
    {% endif %}
{% endmacro %}
